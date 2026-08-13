import '../models/models.dart';
import '../models/shipping_label_data.dart';

/// One candidate customer the matching engine considered, with the score
/// and the specific reason it scored that way — shown to staff verbatim
/// on the manual-review screen so a match is never a black box.
class CustomerMatchCandidate {
  final Customer customer;
  final double score; // 0-100
  final String reason;

  const CustomerMatchCandidate({
    required this.customer,
    required this.score,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'customerId': customer.id,
    'customerName': customer.name,
    'mailboxNumber': customer.mailboxNumber,
    'score': score,
    'reason': reason,
  };
}

enum MatchStatus { autoMatched, needsReview, unknown }

class CustomerMatchResult {
  final List<CustomerMatchCandidate> candidates; // sorted, best first
  final MatchStatus status;

  const CustomerMatchResult({required this.candidates, required this.status});

  CustomerMatchCandidate? get best => candidates.isEmpty ? null : candidates.first;
  double get bestScore => best?.score ?? 0;
}

/// Tiered customer-matching engine. Never auto-assigns on a bare fuzzy
/// name match alone — see the scoring tiers below, which mirror the
/// specification exactly. A label's OCR/barcode data is compared against
/// every candidate customer and each customer gets the HIGHEST score any
/// single signal produced for them (not summed — a strong match on one
/// signal is what matters, not stacking weak ones).
class CustomerMatchService {
  final double autoMatchThreshold;
  final double manualReviewThreshold;

  const CustomerMatchService({
    this.autoMatchThreshold = 90,
    this.manualReviewThreshold = 70,
  });

  /// [expectedTrackingNumbers] maps a tracking number already known to be
  /// expected for a customer (e.g. from pre_alerts) to that customer's id
  /// — tier "tracking number exact match", scored the same as a customer
  /// code hit.
  CustomerMatchResult match({
    required ShippingLabelData label,
    required List<Customer> customers,
    Map<String, String> expectedTrackingNumbers = const {},
  }) {
    final scored = <CustomerMatchCandidate>[];

    for (final customer in customers) {
      double best = 0;
      String reason = '';

      void consider(double score, String why) {
        if (score > best) {
          best = score;
          reason = why;
        }
      }

      // Tier: customer ID (mailbox_number) appearing verbatim in the OCR
      // text — the strongest possible signal, since it's a code this
      // company itself assigned.
      final code = customer.mailboxNumber.trim();
      if (code.isNotEmpty &&
          label.normalizedOcrText.toUpperCase().contains(code.toUpperCase())) {
        consider(100, 'Customer ID "$code" found on label');
      }

      // Tier: tracking number matches an expected/pre-alerted shipment for
      // this customer.
      final tracking = label.trackingNumber?.trim();
      if (tracking != null && tracking.isNotEmpty) {
        final expectedCustomerId = expectedTrackingNumbers[tracking];
        if (expectedCustomerId == customer.id) {
          consider(100, 'Tracking number matches an expected shipment for this customer');
        }
      }

      // Tier: phone exact match (normalized to digits only).
      final labelPhone = _digitsOnly(label.phone);
      final customerPhone = _digitsOnly(customer.phone);
      if (labelPhone != null &&
          customerPhone != null &&
          labelPhone.length >= 10 &&
          labelPhone == customerPhone) {
        consider(95, 'Phone number matches customer record exactly');
      }

      // Tier: email exact match.
      final labelEmail = label.email?.trim().toLowerCase();
      final customerEmail = customer.email.trim().toLowerCase();
      if (labelEmail != null && labelEmail.isNotEmpty && customerEmail.isNotEmpty && labelEmail == customerEmail) {
        consider(95, 'Email matches customer record exactly');
      }

      // Tier: address exact match (line1 + city + postal, normalized).
      final labelAddrKey = _addressKey(label.addressLine1, label.city, label.postalCode);
      final customerAddrKey = _addressKeyFromFreeText(customer.address);
      final addressExact = labelAddrKey != null &&
          customerAddrKey != null &&
          labelAddrKey.isNotEmpty &&
          labelAddrKey == customerAddrKey;
      final hasRecipientName = (label.recipientName ?? '').trim().isNotEmpty;

      // "Address exact match" is its own tier only when there's no
      // recipient name to cross-check at all (OCR found a clear address
      // but no name) — if a name WAS extracted, the name-aware tiers just
      // below take over instead. Address-alone must never simply outrank
      // "name fuzzy + address", or that tier could never win: an
      // unconditional address-only 90 would always fire first and the
      // fuzzy-name case would never be reachable.
      if (addressExact && !hasRecipientName) {
        consider(90, 'Shipping address matches customer record exactly (no recipient name to cross-check)');
      }

      final nameSimilarity = _nameSimilarity(label.recipientName, customer.name);
      final nameExact = nameSimilarity >= 0.98;
      final nameFuzzy = nameSimilarity >= 0.72;

      if (nameExact && addressExact) {
        consider(90, 'Recipient name and address match customer record exactly');
      } else if (nameFuzzy && addressExact) {
        consider(
          80,
          'Recipient name closely matches ("${label.recipientName}" ~ "${customer.name}") and address matches exactly',
        );
      } else if (nameFuzzy) {
        consider(
          50,
          'Recipient name is a close match ("${label.recipientName}" ~ "${customer.name}") but nothing else corroborates it',
        );
      }

      if (best > 0) {
        scored.add(CustomerMatchCandidate(customer: customer, score: best, reason: reason));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final top = scored.isEmpty ? 0.0 : scored.first.score;
    final status = top >= autoMatchThreshold
        ? MatchStatus.autoMatched
        : top >= manualReviewThreshold
        ? MatchStatus.needsReview
        : MatchStatus.unknown;

    return CustomerMatchResult(candidates: scored.take(5).toList(), status: status);
  }

  static String? _digitsOnly(String? s) {
    if (s == null) return null;
    final d = s.replaceAll(RegExp(r'[^0-9]'), '');
    // Drop a leading US/Canada country code so "+1 302 555 0134" lines up
    // with a customer record stored as "302-555-0134".
    if (d.length == 11 && d.startsWith('1')) return d.substring(1);
    return d.isEmpty ? null : d;
  }

  static String? _addressKey(String? line1, String? city, String? postal) {
    if (line1 == null || line1.trim().isEmpty) return null;
    final parts = [line1, city ?? '', postal ?? '']
        .map(_normalizeForCompare)
        .where((p) => p.isNotEmpty);
    return parts.join('|');
  }

  /// customers.address today is a single free-text field (no separate
  /// line1/city/postal columns) — normalize the whole thing and compare
  /// against the label's address rendered the same way, rather than
  /// requiring the free-text field to be split into parts it was never
  /// structured into.
  static String? _addressKeyFromFreeText(String address) {
    final norm = _normalizeForCompare(address);
    return norm.isEmpty ? null : norm;
  }

  static String _normalizeForCompare(String s) {
    return s
        .toUpperCase()
        .replaceAll(RegExp(r'[.,#]'), '')
        .replaceAll(RegExp(r'\bSTREET\b'), 'ST')
        .replaceAll(RegExp(r'\bAVENUE\b'), 'AVE')
        .replaceAll(RegExp(r'\bROAD\b'), 'RD')
        .replaceAll(RegExp(r'\bAPARTMENT\b'), 'APT')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Case/whitespace-insensitive similarity in [0, 1], using normalized
  /// Levenshtein edit distance over the full name string. Good enough to
  /// catch OCR/typo-level differences ("Jon Smth" vs "John Smith") without
  /// a fuzzy-matching package dependency.
  static double _nameSimilarity(String? a, String b) {
    if (a == null || a.trim().isEmpty || b.trim().isEmpty) return 0;
    final x = _normalizeForCompare(a);
    final y = _normalizeForCompare(b);
    if (x == y) return 1.0;
    final dist = _levenshtein(x, y);
    final maxLen = x.length > y.length ? x.length : y.length;
    if (maxLen == 0) return 1.0;
    return 1.0 - (dist / maxLen);
  }

  static int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final curr = List<int>.filled(b.length + 1, 0);
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          curr[j - 1] + 1,
          prev[j] + 1,
          prev[j - 1] + cost,
        ].reduce((v, e) => v < e ? v : e);
      }
      prev = curr;
    }
    return prev[b.length];
  }
}
