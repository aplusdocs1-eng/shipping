/// Typed, merge-safe accessor over a partner's public branding data (the
/// curated `branding` object returned by get_partner_by_domain /
/// get_partner_by_code — see TenantService.branding). Every getter falls
/// back to null/empty when a courier hasn't customized that field, so
/// callers always pair this with their own hardcoded default — the same
/// "never break, blank means default" principle as LandingContent.
class PartnerBranding {
  final Map<String, dynamic> data;
  const PartnerBranding(this.data);

  factory PartnerBranding.from(Map<String, dynamic>? raw) =>
      PartnerBranding(raw ?? const {});

  /// ARGB color value (as saved by the color-swatch picker), or null.
  int? get color {
    final v = data['color'];
    if (v is num) return v.toInt();
    return null;
  }

  String? get portalTitle => _str('portalTitle');
  String? get subtitle => _str('subtitle');
  String? get logoUrl => _str('logoUrl');
  String? get heroImageUrl => _str('heroImageUrl');

  List<String> get features {
    final v = data['features'];
    if (v is List) {
      return v.whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    }
    return const [];
  }

  String? _str(String key) {
    final v = data[key];
    if (v is String && v.trim().isNotEmpty) return v;
    return null;
  }
}
