import 'package:flutter_test/flutter_test.dart';
import 'package:courierwarehousing/services/shipping_label_parser.dart';

void main() {
  group('CarrierDetector', () {
    test('UPS 1Z tracking number is detected with high confidence', () {
      final r = CarrierDetector.detect('1Z999AA10123456784');
      expect(r.carrier, 'UPS');
      expect(r.confidence, greaterThanOrEqualTo(0.9));
    });

    test('Amazon Logistics TBA tracking number is detected', () {
      final r = CarrierDetector.detect('TBA123456789012');
      expect(r.carrier, 'Amazon Logistics');
      expect(r.confidence, greaterThanOrEqualTo(0.9));
    });

    test('USPS international format (XX#########US) is detected', () {
      final r = CarrierDetector.detect('EC123456785US');
      expect(r.carrier, 'USPS');
    });

    test('Royal Mail format (XX#########GB) is detected', () {
      final r = CarrierDetector.detect('AB123456785GB');
      expect(r.carrier, 'Royal Mail');
      expect(r.confidence, greaterThanOrEqualTo(0.9));
    });

    test('DHL JJD-prefixed format is detected with high confidence', () {
      final r = CarrierDetector.detect('JJD0012345678901234');
      expect(r.carrier, 'DHL');
      expect(r.confidence, greaterThanOrEqualTo(0.85));
    });

    test('ambiguous 12-digit numeric guesses FedEx but with LOW confidence', () {
      final r = CarrierDetector.detect('123456789012');
      // A bare 12-digit number is genuinely ambiguous (FedEx/DHL overlap)
      // — the whole point of probabilistic detection is this must never
      // read as certain.
      expect(r.confidence, lessThan(0.7));
    });

    test('unrecognizable value falls back to Other with very low confidence', () {
      final r = CarrierDetector.detect('NOT-A-REAL-TRACKING-CODE!!');
      expect(r.carrier, 'Other');
      expect(r.confidence, lessThan(0.3));
    });

    test('empty value never claims a carrier', () {
      final r = CarrierDetector.detect('');
      expect(r.confidence, 0.0);
    });
  });

  group('ShippingLabelParser — OCR normalization', () {
    test('fixes O/0, I/1, S/5, B/8 confusion inside numeric-looking runs', () {
      // "1Z999AA1O123456784" (letter O where a 0 belongs) should normalize
      // to the real tracking number shape.
      final normalized = ShippingLabelParser.normalizeOcrText('1Z999AA1O123456784');
      expect(normalized, '1Z999AA10123456784');
    });

    test('does NOT touch ordinary words that happen to contain those letters', () {
      final normalized = ShippingLabelParser.normalizeOcrText('SHIP TO Boston');
      expect(normalized, 'SHIP TO Boston');
    });

    test('never modifies rawOcrText, only the normalized copy', () {
      const raw = 'SHIP TO\nJohn Smith\n1Z999AA1O123456784';
      final label = const ShippingLabelParser().parse(rawOcrText: raw);
      expect(label.rawOcrText, raw);
      expect(label.normalizedOcrText, isNot(raw));
    });
  });

  group('ShippingLabelParser — carrier label extraction', () {
    const parser = ShippingLabelParser();

    test('UPS label: recipient, address, and tracking all extracted', () {
      const ocr = '''
UPS GROUND
SHIP TO:
John Smith
123 Main Street
Newark, DE 19711
1Z999AA10123456784
''';
      final label = parser.parse(rawOcrText: ocr);
      expect(label.trackingNumber, '1Z999AA10123456784');
      expect(label.carrier, 'UPS');
      expect(label.recipientName, 'John Smith');
      expect(label.addressLine1, '123 Main Street');
      expect(label.city, 'Newark');
      expect(label.state, 'DE');
      expect(label.postalCode, '19711');
      expect(label.confidenceFor('trackingNumber'), greaterThan(0.8));
    });

    test('USPS label with order number is extracted', () {
      const ocr = '''
USPS PRIORITY MAIL
SHIP TO:
Marcia Williams
45 Ocean Ave
Kingston, JA
Order # 111-2223334-5556667
9400111899560123456785
''';
      final label = parser.parse(rawOcrText: ocr);
      expect(label.orderNumber, '111-2223334-5556667');
      expect(label.recipientName, 'Marcia Williams');
    });

    test('FedEx label with a barcode value passed in trusts the barcode over OCR guesswork', () {
      const ocr = '''
FedEx Ground
SHIP TO:
Devon Brown
78 Palm Street
Montego Bay, JA
''';
      final label = parser.parse(
        rawOcrText: ocr,
        barcodeValue: '789123456789',
        barcodeType: 'CODE_128',
      );
      expect(label.trackingNumber, '789123456789');
      expect(label.confidenceFor('trackingNumber'), 1.0);
      expect(label.barcodeValue, '789123456789');
    });

    test('DHL label is extracted', () {
      const ocr = '''
DHL EXPRESS
DECONSIGNEE:
Priya Patel
9 Harbour Road
Kingston, JA
JJD0018273645509182
''';
      final label = parser.parse(rawOcrText: ocr);
      expect(label.carrier, 'DHL');
    });

    test('Amazon package (TBA barcode) with no marketplace customer data — '
        'OCR/label is still the only source of recipient info', () {
      const ocr = '''
SHIP TO
Alicia Green
221 Baker Street
Ocho Rios, JA
''';
      final label = parser.parse(rawOcrText: ocr, barcodeValue: 'TBA123456789012');
      expect(label.carrier, 'Amazon Logistics');
      expect(label.recipientName, 'Alicia Green');
      // Nothing about "Amazon Logistics" as a carrier implies real
      // customer/account data — it's still 100% OCR-derived.
    });

    test('eBay-shipped package (generic carrier label, no special-casing needed)', () {
      const ocr = '''
SHIP TO:
Robert King
12 Fern Gully Rd
Ocho Rios, JA
USPS GROUND ADVANTAGE
''';
      final label = parser.parse(rawOcrText: ocr);
      expect(label.recipientName, 'Robert King');
      expect(label.serviceType, isNotNull);
    });

    test('poor OCR (garbled, missing structure) never crashes and returns nulls '
        'rather than invented data', () {
      const ocr = 'asdkj 12l3 ##\$%\n\n   ';
      final label = parser.parse(rawOcrText: ocr);
      expect(label.recipientName, isNull);
      expect(label.trackingNumber, isNull);
      // Confidence map has no entries for fields that were never found.
      expect(label.confidenceFor('recipientName'), 0.0);
    });

    test('missing recipient (no SHIP TO block at all) leaves recipient fields null, '
        'not a guessed value', () {
      const ocr = '''
TRACKING: 1Z999AA10123456784
UPS GROUND
''';
      final label = parser.parse(rawOcrText: ocr);
      expect(label.recipientName, isNull);
      expect(label.trackingNumber, '1Z999AA10123456784');
    });

    test('international address (Canadian postal code format) is recognized', () {
      const ocr = '''
SHIP TO:
Emily Tremblay
200 Rue Principale
Montreal QC H2X 1Y6
CANADA
''';
      final label = parser.parse(rawOcrText: ocr);
      expect(label.postalCode, 'H2X 1Y6');
      expect(label.country, 'CANADA');
    });

    test('every field is nullable and none are ever invented for a bare-barcode scan', () {
      final label = parser.parse(rawOcrText: '', barcodeValue: '1Z999AA10123456784');
      expect(label.recipientName, isNull);
      expect(label.addressLine1, isNull);
      expect(label.trackingNumber, '1Z999AA10123456784');
    });

    test('weight is extracted when present on the label', () {
      const ocr = 'SHIP TO:\nJohn Smith\n123 Main St\nNewark DE 19711\nWEIGHT: 4.2 LBS';
      final label = parser.parse(rawOcrText: ocr);
      expect(label.packageWeight, 4.2);
    });
  });
}
