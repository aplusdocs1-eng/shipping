import 'package:flutter/material.dart';

/// Canonical schema + defaults for every admin-editable piece of copy,
/// number, image, and icon on the public landing page.
///
/// The landing page always renders `LandingContent.merged(overridesFromDb)`
/// — defaults filled in for anything the admin hasn't customized — so the
/// page can never end up blank or broken from partial data, and a brand
/// new/empty `site_content` row renders identically to the page as
/// originally designed.
///
/// The admin Site Content editor (site_content_screen.dart) reads/writes
/// the exact same section/field keys, so this file is the single source of
/// truth for the shape of the content on both sides.
class LandingContent {
  final Map<String, dynamic> data;
  const LandingContent(this.data);

  factory LandingContent.merged(Map<String, dynamic>? overrides) {
    return LandingContent(_deepMerge(defaults, overrides ?? const {}));
  }

  static Map<String, dynamic> _deepMerge(
    Map<String, dynamic> base,
    Map<String, dynamic> override,
  ) {
    final result = <String, dynamic>{};
    base.forEach((key, value) => result[key] = value);
    override.forEach((key, value) {
      final baseValue = result[key];
      if (value is Map &&
          baseValue is Map<String, dynamic> &&
          value is Map<String, dynamic>) {
        result[key] = _deepMerge(baseValue, value);
      } else if (value != null) {
        result[key] = value;
      }
    });
    return result;
  }

  Map<String, dynamic> _section(String key) {
    final s = data[key];
    return s is Map<String, dynamic> ? s : const {};
  }

  String str(String section, String field) {
    final v = _section(section)[field];
    return v is String ? v : '';
  }

  /// Empty string means "use the bundled asset" for image fields.
  String img(String section, String field) => str(section, field);

  List<Map<String, dynamic>> list(String section, String field) {
    final v = _section(section)[field];
    if (v is List) return v.whereType<Map<String, dynamic>>().toList();
    return const [];
  }

  // ─── Icon registry ─────────────────────────────────────────────────────
  // A curated, fixed set of icons an admin can assign to service / feature
  // items via a dropdown — keeps content data JSON/string-safe (no IconData
  // in the database) while still letting the visual identity of each card
  // be customized, not just its text.
  static const Map<String, IconData> icons = {
    'local_shipping': Icons.local_shipping_outlined,
    'directions_boat': Icons.directions_boat_outlined,
    'flight': Icons.flight_outlined,
    'warehouse': Icons.warehouse_outlined,
    'fact_check': Icons.fact_check_outlined,
    'inventory': Icons.inventory_2_outlined,
    'public': Icons.public,
    'groups': Icons.groups_outlined,
    'shield': Icons.shield_outlined,
    'attach_money': Icons.attach_money,
    'support_agent': Icons.support_agent_outlined,
    'verified_user': Icons.verified_user_outlined,
    'schedule': Icons.schedule_outlined,
    'headset_mic': Icons.headset_mic_outlined,
    'location_on': Icons.location_on_outlined,
    'phone': Icons.phone_outlined,
    'email': Icons.email_outlined,
    'star': Icons.star_outline,
    'thumb_up': Icons.thumb_up_outlined,
    'handshake': Icons.handshake_outlined,
    'eco': Icons.eco_outlined,
    'speed': Icons.speed_outlined,
    'security': Icons.security_outlined,
    'business': Icons.business_outlined,
    'map': Icons.map_outlined,
    'track_changes': Icons.track_changes_outlined,
    'payments': Icons.payments_outlined,
    'person': Icons.person_outline,
  };

  static IconData iconFor(String key, IconData fallback) =>
      icons[key] ?? fallback;

  static const List<String> iconKeys = [
    'local_shipping',
    'directions_boat',
    'flight',
    'warehouse',
    'fact_check',
    'inventory',
    'public',
    'groups',
    'shield',
    'attach_money',
    'support_agent',
    'verified_user',
    'schedule',
    'headset_mic',
    'location_on',
    'phone',
    'email',
    'star',
    'thumb_up',
    'handshake',
    'eco',
    'speed',
    'security',
    'business',
    'map',
    'track_changes',
    'payments',
    'person',
  ];

  // ─── Defaults ──────────────────────────────────────────────────────────
  // This is the page's copy exactly as originally hand-built — it must
  // stay in sync in spirit (not necessarily every literal string) with
  // what landing_screen.dart renders when a field is left uncustomized.
  static const Map<String, dynamic> defaults = {
    'contact': {
      'phone': '267-844-5155',
      'address': 'Hollywood, Florida',
      'email': 'shipping@onevillageshipping.com',
    },
    'hero': {
      'titleLine1': 'ONE VILLAGE.',
      'titleLine2': 'GLOBAL REACH.',
      'subtitle':
          'Your trusted partner for shipping, freight, and delivery solutions worldwide.',
      'primaryButtonText': 'GET STARTED',
      'secondaryButtonText': 'TRACK SHIPMENT',
      'backgroundImageUrl': '',
      'originLabel': 'WE SHIP FROM',
      'originText': 'ANYWHERE IN THE U.S.A.',
      'destLabel': 'TO KINGSTON, JA',
      'destText': 'via sea and air freight',
    },
    'knutsford': {
      'enabled': true,
      'titlePrefix': 'Knutsford ',
      'titleSuffix': 'Express',
      'subtitle': 'EXPRESS SERVICES TO KNUTSFORD EXPRESS LOCATIONS',
      'badge': 'ISLANDWIDE',
      'dialogBody':
          'One Village Shipping & Freight offers express delivery to Knutsford Express locations islandwide — a fast, convenient pickup option for customers across Jamaica.',
    },
    'services': {
      'eyebrow': 'OUR SERVICES',
      'heading': 'Comprehensive Solutions. Delivered.',
      'items': [
        {
          'icon': 'directions_boat',
          'title': 'Sea Freight',
          'description':
              'Reliable and cost-effective ocean shipping to destinations worldwide.',
          'detail':
              'Cost-effective ocean freight from anywhere in the USA to Kingston, Jamaica. Ideal for large or heavy shipments, with flexible container and consolidation options.',
          'imageUrl': '',
        },
        {
          'icon': 'flight',
          'title': 'Air Freight',
          'description':
              'Fast and secure air cargo solutions when time matters.',
          'detail':
              'Fast, secure air cargo for time-sensitive shipments — from the USA to Kingston in days, not weeks, with full tracking every step of the way.',
          'imageUrl': '',
        },
        {
          'icon': 'warehouse',
          'title': 'Warehousing',
          'description':
              'Secure storage, inventory management, and distribution.',
          'detail':
              'Secure, monitored storage with professional inventory management and distribution — your goods are safe and organized from arrival to dispatch.',
          'imageUrl': '',
        },
        {
          'icon': 'local_shipping',
          'title': 'Door to Door',
          'description':
              'Complete delivery solution from our warehouse to your door.',
          'detail':
              'We handle the entire journey — from pickup at our USA warehouse straight to your door in Jamaica, no extra steps required.',
          'imageUrl': '',
        },
        {
          'icon': 'fact_check',
          'title': 'Customs Clearance',
          'description': 'Expert documentation and fast customs clearance.',
          'detail':
              'Expert documentation and fast customs processing so your shipment clears without delays or surprises.',
          'imageUrl': '',
        },
      ],
    },
    'whyChooseUs': {
      'eyebrow': 'WHY CHOOSE US',
      'heading': 'We go the extra mile for your cargo.',
      'items': [
        {
          'icon': 'groups',
          'title': 'Experienced Team',
          'description': 'Professionals with years of industry expertise.',
        },
        {
          'icon': 'shield',
          'title': 'Secure & Reliable',
          'description': 'Your cargo is safe with us.',
        },
        {
          'icon': 'attach_money',
          'title': 'Competitive Rates',
          'description': 'Quality service at the best value.',
        },
        {
          'icon': 'public',
          'title': 'Global Coverage',
          'description': 'Strong network across the world.',
        },
        {
          'icon': 'support_agent',
          'title': '24/7 Customer Support',
          'description': "We're here whenever you need us.",
        },
      ],
    },
    'stats': {
      'items': [
        {'value': '10+', 'label': 'YEARS EXPERIENCE'},
        {'value': '50,000+', 'label': 'SHIPMENTS DELIVERED'},
        {'value': '100+', 'label': 'COUNTRIES SERVED'},
        {'value': '5,000+', 'label': 'SATISFIED CUSTOMERS'},
      ],
    },
    'cta': {
      'eyebrow': 'Ready to ship?',
      'heading': "Let's move your world forward.",
      'subtitle':
          'Get a free quote today and experience the One Village difference.',
      'courierCardTitle': 'COURIER SIGN UP',
      'courierCardDesc':
          'Partner with us to manage your own customers and shipments.',
      'customerCardTitle': 'CUSTOMER SIGN UP',
      'customerCardDesc': 'Create an account to ship faster and easier.',
      'imageUrl': '',
    },
    'footer': {
      'tagline':
          'Your trusted partner for shipping, freight, and delivery solutions worldwide.',
      'copyrightName': 'One Village Shipping & Freight LLC',
    },
    'about': {
      'body':
          'One Village Shipping & Freight is your trusted partner for shipping, freight, and delivery solutions worldwide — connecting the USA to Kingston, Jamaica via sea and air freight, with secure warehousing, door-to-door delivery, and expert customs clearance.',
    },
    'rates': {
      'body':
          'Create a free account to get instant, personalized rates for sea and air freight, plus door-to-door and customs clearance pricing.',
    },
  };
}
