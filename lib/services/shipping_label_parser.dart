import '../models/shipping_label_data.dart';

/// Parses OCR text (plus, optionally, an already-scanned barcode value)
/// off a shipping label into structured fields.
///
/// This is deliberately heuristic, not magic: real labels from Amazon,
/// eBay, UPS, FedEx, USPS, DHL, and everyone else lay information out
/// differently, and OCR text from a phone/webcam photo is noisy. Every
/// extracted field carries a confidence score reflecting how specific the
/// signal that found it was — a regex match on a definitive carrier
/// tracking-number format scores much higher than "this was the first line
/// after the word SHIP TO". Nothing here invents a value that isn't
/// actually traceable to the input text.
class ShippingLabelParser {
  const ShippingLabelParser();

  ShippingLabelData parse({required String rawOcrText, String? barcodeValue, String? barcodeType}) {
    final normalized = normalizeOcrText(rawOcrText);
    final lines = normalized
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final confidence = <String, double>{};

    // Tracking number: the barcode itself is the most reliable source when
    // present (a human/QR/1D scanner already resolved it exactly) — OCR is
    // only the fallback when there's no barcode, or to cross-check it.
    String? trackingNumber;
    String? carrier;
    double carrierConfidence = 0.0;
    if (barcodeValue != null && barcodeValue.trim().isNotEmpty) {
      trackingNumber = barcodeValue.trim();
      confidence['trackingNumber'] = 1.0;
      final detected = CarrierDetector.detect(trackingNumber);
      carrier = detected.carrier;
      carrierConfidence = detected.confidence;
    } else {
      final found = _findTrackingNumberInText(normalized);
      if (found != null) {
        trackingNumber = found.value;
        confidence['trackingNumber'] = found.confidence;
        final detected = CarrierDetector.detect(found.value);
        carrier = detected.carrier;
        carrierConfidence = detected.confidence;
      }
    }
    if (carrier != null) confidence['carrier'] = carrierConfidence;

    final orderNumber = _captureAfterLabel(lines, [
      'order #',
      'order number',
      'order id',
      'order:',
    ]);
    if (orderNumber != null) confidence['orderNumber'] = 0.75;

    final referenceNumber = _captureAfterLabel(lines, [
      'ref #',
      'reference #',
      'reference number',
      'ref:',
      'po #',
      'po number',
    ]);
    if (referenceNumber != null) confidence['referenceNumber'] = 0.7;

    final shipToBlock = _extractSectionBlock(
      lines,
      startMarkers: ['ship to', 'deliver to', 'consignee', 'to:'],
      endMarkers: ['ship from', 'from:', 'return address', 'sold by', 'order #', 'order number'],
    );
    final recipient = _parseAddressBlock(shipToBlock);

    final shipFromBlock = _extractSectionBlock(
      lines,
      startMarkers: ['ship from', 'from:', 'return address', 'sender'],
      endMarkers: ['ship to', 'deliver to', 'to:', 'order #'],
    );
    final sender = _parseAddressBlock(shipFromBlock);

    if (recipient.name != null) confidence['recipientName'] = recipient.nameConfidence;
    if (recipient.company != null) confidence['recipientCompany'] = 0.55;
    if (recipient.addressLine1 != null) confidence['addressLine1'] = recipient.addressConfidence;
    if (recipient.city != null) confidence['city'] = recipient.addressConfidence;
    if (recipient.state != null) confidence['state'] = recipient.addressConfidence;
    if (recipient.postalCode != null) confidence['postalCode'] = recipient.postalConfidence;
    if (recipient.country != null) confidence['country'] = 0.6;

    final phone = _findPhone(normalized);
    if (phone != null) confidence['phone'] = 0.85;
    final email = _findEmail(normalized);
    if (email != null) confidence['email'] = 0.9;

    final weight = _findWeight(normalized);
    if (weight != null) confidence['packageWeight'] = 0.6;

    final serviceType = _findServiceType(normalized);
    if (serviceType != null) confidence['serviceType'] = 0.65;

    return ShippingLabelData(
      recipientName: recipient.name,
      recipientCompany: recipient.company,
      addressLine1: recipient.addressLine1,
      addressLine2: recipient.addressLine2,
      city: recipient.city,
      state: recipient.state,
      province: recipient.state,
      postalCode: recipient.postalCode,
      country: recipient.country,
      phone: phone,
      email: email,
      trackingNumber: trackingNumber,
      orderNumber: orderNumber,
      referenceNumber: referenceNumber,
      carrier: carrier,
      serviceType: serviceType,
      senderName: sender.name,
      senderAddress: sender.addressLine1,
      senderCity: sender.city,
      senderState: sender.state,
      senderPostalCode: sender.postalCode,
      senderCountry: sender.country,
      packageWeight: weight,
      rawOcrText: rawOcrText,
      normalizedOcrText: normalized,
      barcodeValue: barcodeValue,
      barcodeType: barcodeType,
      confidence: confidence,
    );
  }

  /// OCR-mistake-aware cleanup: collapses the classic confusions (O<->0,
  /// I<->1, S<->5, B<->8, and a few others) but ONLY inside runs that are
  /// already mostly digits — i.e. only where the run looks like it was
  /// meant to be a number (a tracking number, postal code, phone number),
  /// never inside ordinary words. This never touches rawOcrText itself;
  /// callers that need the untouched original still have it.
  static String normalizeOcrText(String text) {
    // replaceAllMapped (not split+rejoin) specifically because Dart's
    // String.split(RegExp) discards the delimiter text even when the
    // pattern captures it (unlike JS's String.split, which keeps captured
    // delimiters) — a split/rejoin here silently ate every space between
    // words. replaceAllMapped only touches the matched word tokens and
    // leaves everything else (spaces, newlines) exactly as it was.
    return text.replaceAllMapped(RegExp(r'\S+'), (m) => _normalizeToken(m.group(0)!));
  }

  static String _normalizeToken(String token) {
    if (token.trim().isEmpty) return token;
    final alnum = token.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (alnum.isEmpty) return token;
    final digitCount = alnum.replaceAll(RegExp(r'[^0-9]'), '').length;
    // Only treat as "meant to be numeric" once digits are a clear majority
    // — a token like "S123" (half letters) stays untouched, but "51O23"
    // (one stray letter in an otherwise-numeric run) gets fixed.
    if (digitCount < alnum.length * 0.6 || alnum.length < 3) return token;
    var out = token;
    const confusions = {
      'O': '0',
      'o': '0',
      'I': '1',
      'l': '1',
      'S': '5',
      'B': '8',
    };
    confusions.forEach((from, to) {
      out = out.replaceAll(from, to);
    });
    return out;
  }

  _TrackingMatch? _findTrackingNumberInText(String text) {
    // Look for the most carrier-specific patterns first (highest
    // confidence), then fall back to a generic long-alphanumeric guess.
    for (final pattern in CarrierDetector.definitivePatterns) {
      final m = pattern.pattern.firstMatch(text.toUpperCase());
      if (m != null) return _TrackingMatch(m.group(0)!, 0.9);
    }
    // Generic fallback: a 10-22 character alphanumeric run near the word
    // "TRACKING" — low confidence, since this is just shape-matching.
    final trackingLabelIdx = text.toLowerCase().indexOf('tracking');
    if (trackingLabelIdx != -1) {
      final after = text.substring(trackingLabelIdx);
      final m = RegExp(r'[A-Z0-9]{10,22}').firstMatch(after.toUpperCase());
      if (m != null) return _TrackingMatch(m.group(0)!, 0.5);
    }
    return null;
  }

  String? _captureAfterLabel(List<String> lines, List<String> labels) {
    for (final line in lines) {
      final lower = line.toLowerCase();
      for (final label in labels) {
        final idx = lower.indexOf(label);
        if (idx != -1) {
          final after = line.substring(idx + label.length).trim();
          final cleaned = after.replaceFirst(RegExp(r'^[:\-\s]+'), '').trim();
          if (cleaned.isNotEmpty) return cleaned;
        }
      }
    }
    return null;
  }

  List<String> _extractSectionBlock(
    List<String> lines, {
    required List<String> startMarkers,
    required List<String> endMarkers,
  }) {
    int start = -1;
    for (var i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      if (startMarkers.any((m) => lower.contains(m))) {
        start = i;
        break;
      }
    }
    if (start == -1) return const [];
    // If the marker line has trailing text after the label itself (e.g.
    // "SHIP TO: John Smith"), that trailing text is part of the block too.
    final block = <String>[];
    final markerLine = lines[start];
    final lowerMarker = markerLine.toLowerCase();
    for (final m in startMarkers) {
      final idx = lowerMarker.indexOf(m);
      if (idx != -1) {
        final trailing = markerLine
            .substring(idx + m.length)
            .replaceFirst(RegExp(r'^[:\-\s]+'), '')
            .trim();
        if (trailing.isNotEmpty) block.add(trailing);
        break;
      }
    }
    for (var i = start + 1; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      if (endMarkers.any((m) => lower.contains(m))) break;
      block.add(lines[i]);
      if (block.length >= 6) break; // an address block is never this long
    }
    return block;
  }

  _ParsedAddress _parseAddressBlock(List<String> block) {
    if (block.isEmpty) return const _ParsedAddress();

    String? name;
    String? company;
    double nameConfidence = 0.0;
    final addressLines = <String>[];
    String? city, state, postalCode, country;
    double addressConfidence = 0.0;
    double postalConfidence = 0.0;

    final cityStateZip = RegExp(
      r'^([A-Za-z .\-]+)[, ]+([A-Z]{2})\s+(\d{5}(-\d{4})?)$',
    );
    final canadianPostal = RegExp(r'[A-Za-z]\d[A-Za-z]\s?\d[A-Za-z]\d');

    for (var i = 0; i < block.length; i++) {
      final line = block[i];
      final cszMatch = cityStateZip.firstMatch(line);
      if (cszMatch != null) {
        city = cszMatch.group(1)?.trim();
        state = cszMatch.group(2);
        postalCode = cszMatch.group(3);
        addressConfidence = 0.85;
        postalConfidence = 0.9;
        continue;
      }
      final caPostal = canadianPostal.firstMatch(line);
      if (caPostal != null && postalCode == null) {
        postalCode = caPostal.group(0)?.toUpperCase();
        postalConfidence = 0.75;
        // Whatever's left on the line (minus the postal code) is likely
        // "City PROVINCE".
        final rest = line.replaceAll(caPostal.group(0)!, '').trim();
        if (rest.isNotEmpty) {
          final parts = rest.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            state = parts.removeLast();
            city = parts.join(' ');
            addressConfidence = 0.6;
          }
        }
        continue;
      }
      if (RegExp(r'^(USA|US|UNITED STATES|CANADA|JAMAICA|UK|UNITED KINGDOM)$', caseSensitive: false)
          .hasMatch(line)) {
        country = line.toUpperCase() == 'US' ? 'USA' : line;
        continue;
      }
      if (name == null && i == 0) {
        // First line of the block is the recipient/sender name, unless it
        // reads like a company (ALL CAPS with a corporate suffix).
        if (RegExp(r'\b(INC|LLC|CORP|CO|LTD|LLP)\b\.?$', caseSensitive: false).hasMatch(line)) {
          company = line;
        } else {
          name = line;
          nameConfidence = 0.7;
        }
        continue;
      }
      if (name != null && company == null && addressLines.isEmpty &&
          RegExp(r'\b(INC|LLC|CORP|CO|LTD|LLP)\b\.?$', caseSensitive: false).hasMatch(line)) {
        company = line;
        continue;
      }
      addressLines.add(line);
    }

    return _ParsedAddress(
      name: name,
      company: company,
      nameConfidence: nameConfidence,
      addressLine1: addressLines.isNotEmpty ? addressLines.first : null,
      addressLine2: addressLines.length > 1 ? addressLines[1] : null,
      city: city,
      state: state,
      postalCode: postalCode,
      country: country,
      addressConfidence: addressLines.isNotEmpty ? (addressConfidence == 0 ? 0.5 : addressConfidence) : 0.0,
      postalConfidence: postalConfidence,
    );
  }

  String? _findPhone(String text) {
    final m = RegExp(
      r'(\+?1[\s\-.]?)?\(?\d{3}\)?[\s\-.]?\d{3}[\s\-.]?\d{4}',
    ).firstMatch(text);
    return m?.group(0)?.trim();
  }

  String? _findEmail(String text) {
    final m = RegExp(
      r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
    ).firstMatch(text);
    return m?.group(0);
  }

  double? _findWeight(String text) {
    final m = RegExp(
      r'(\d+(\.\d+)?)\s*(LBS?|KG|LB)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (m == null) return null;
    return double.tryParse(m.group(1) ?? '');
  }

  String? _findServiceType(String text) {
    const known = [
      'PRIORITY OVERNIGHT',
      'STANDARD OVERNIGHT',
      'OVERNIGHT',
      '2ND DAY AIR',
      '2-DAY',
      'GROUND',
      'EXPRESS',
      'PRIORITY MAIL',
      'PRIORITY',
      'FIRST CLASS',
      'STANDARD',
      'ECONOMY',
    ];
    final upper = text.toUpperCase();
    for (final s in known) {
      if (upper.contains(s)) return s;
    }
    return null;
  }
}

class _TrackingMatch {
  final String value;
  final double confidence;
  _TrackingMatch(this.value, this.confidence);
}

class _ParsedAddress {
  final String? name;
  final String? company;
  final double nameConfidence;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final double addressConfidence;
  final double postalConfidence;

  const _ParsedAddress({
    this.name,
    this.company,
    this.nameConfidence = 0.0,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.addressConfidence = 0.0,
    this.postalConfidence = 0.0,
  });
}

/// Result of CarrierDetector.detect(): a best-guess carrier name plus a
/// 0.0-1.0 confidence — never a bare string, so callers can't
/// accidentally treat a low-confidence guess as certain.
class CarrierGuess {
  final String carrier;
  final double confidence;
  const CarrierGuess(this.carrier, this.confidence);
}

/// Probabilistic carrier detection from a tracking-number-shaped string.
/// Some formats are genuinely definitive (UPS's "1Z" prefix, Amazon
/// Logistics' "TBA" prefix, Royal Mail's "..GB" suffix); others (plain
/// 10-15 digit numeric strings, which FedEx, DHL, and Canada Post all use
/// in overlapping ranges) are inherently ambiguous, and get a
/// correspondingly lower confidence rather than a false claim of certainty.
class CarrierDetector {
  const CarrierDetector._();

  static CarrierGuess detect(String value) {
    final v = value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (v.isEmpty) return const CarrierGuess('Unknown', 0.0);

    if (RegExp(r'^1Z[0-9A-Z]{16}$').hasMatch(v)) {
      return const CarrierGuess('UPS', 0.98);
    }
    if (RegExp(r'^TBA[0-9]{12}$').hasMatch(v)) {
      return const CarrierGuess('Amazon Logistics', 0.95);
    }
    if (RegExp(r'^[A-Z]{2}[0-9]{9}GB$').hasMatch(v)) {
      return const CarrierGuess('Royal Mail', 0.95);
    }
    if (RegExp(r'^[A-Z]{2}[0-9]{9}US$').hasMatch(v)) {
      return const CarrierGuess('USPS', 0.92);
    }
    if (RegExp(r'^(94|93|92|95|420)[0-9]{18,20}$').hasMatch(v)) {
      return const CarrierGuess('USPS', 0.85);
    }
    if (RegExp(r'^[0-9]{22}$').hasMatch(v)) {
      return const CarrierGuess('USPS', 0.6);
    }
    if (RegExp(r'^[0-9]{12}$').hasMatch(v)) {
      // FedEx Express is the single most common issuer of this exact
      // shape, but it's not definitive — DHL and a few others overlap.
      return const CarrierGuess('FedEx', 0.55);
    }
    if (RegExp(r'^[0-9]{15}$').hasMatch(v)) {
      return const CarrierGuess('FedEx', 0.7);
    }
    if (RegExp(r'^[0-9]{10,11}$').hasMatch(v)) {
      return const CarrierGuess('DHL', 0.5);
    }
    if (RegExp(r'^[0-9]{16}$').hasMatch(v)) {
      return const CarrierGuess('Canada Post', 0.5);
    }
    if (RegExp(r'^JJD[0-9]{16,18}$').hasMatch(v)) {
      return const CarrierGuess('DHL', 0.9);
    }
    return const CarrierGuess('Other', 0.2);
  }

  /// Definitive (high-confidence, non-overlapping) patterns only — used by
  /// ShippingLabelParser to scan free-form OCR text for a tracking number
  /// it hasn't already got from a barcode. Deliberately excludes the
  /// ambiguous pure-numeric shapes above, since matching e.g. "any 12
  /// digits" against a whole page of OCR text would find false positives
  /// constantly (order numbers, phone numbers, zip+4s).
  static final definitivePatterns = [
    _NamedPattern('UPS', RegExp(r'1Z[0-9A-Z]{16}')),
    _NamedPattern('Amazon Logistics', RegExp(r'TBA[0-9]{12}')),
    _NamedPattern('Royal Mail', RegExp(r'[A-Z]{2}[0-9]{9}GB')),
    _NamedPattern('USPS', RegExp(r'[A-Z]{2}[0-9]{9}US')),
    _NamedPattern('DHL', RegExp(r'JJD[0-9]{16,18}')),
  ];
}

class _NamedPattern {
  final String carrier;
  final RegExp pattern;
  _NamedPattern(this.carrier, this.pattern);
}
