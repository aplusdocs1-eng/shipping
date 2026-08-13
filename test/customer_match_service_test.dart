import 'package:flutter_test/flutter_test.dart';
import 'package:courierwarehousing/models/models.dart';
import 'package:courierwarehousing/models/shipping_label_data.dart';
import 'package:courierwarehousing/services/customer_match_service.dart';

Customer _customer({
  required String id,
  required String name,
  String email = '',
  String phone = '',
  String address = '',
  String mailboxNumber = '',
}) {
  return Customer(
    id: id,
    name: name,
    email: email,
    phone: phone,
    address: address,
    city: '',
    country: '',
    joinedAt: DateTime(2026, 1, 1),
    totalPackages: 0,
    balance: 0,
    isActive: true,
    mailboxNumber: mailboxNumber,
  );
}

ShippingLabelData _label({
  String? recipientName,
  String? addressLine1,
  String? city,
  String? postalCode,
  String? phone,
  String? email,
  String rawText = '',
}) {
  return ShippingLabelData(
    recipientName: recipientName,
    addressLine1: addressLine1,
    city: city,
    postalCode: postalCode,
    phone: phone,
    email: email,
    rawOcrText: rawText,
    normalizedOcrText: rawText,
  );
}

void main() {
  const service = CustomerMatchService(); // default thresholds: 90 / 70

  test('customer code (mailbox_number) found on the label is a 100% auto-match', () {
    final customers = [
      _customer(id: '1', name: 'Marcia Williams', mailboxNumber: 'HDS-1001'),
      _customer(id: '2', name: 'Devon Brown', mailboxNumber: 'HDS-1002'),
    ];
    final label = _label(
      recipientName: 'M Williams',
      rawText: 'SHIP TO\nHDS-1001\nM Williams\n45 Ocean Ave',
    );
    final result = service.match(label: label, customers: customers);
    expect(result.status, MatchStatus.autoMatched);
    expect(result.best!.customer.id, '1');
    expect(result.bestScore, 100);
  });

  test('tracking number matching an expected shipment is a 100% match', () {
    final customers = [_customer(id: '1', name: 'John Smith')];
    final label = ShippingLabelData(
      trackingNumber: '1Z999AA10123456784',
      rawOcrText: '',
      normalizedOcrText: '',
    );
    final result = service.match(
      label: label,
      customers: customers,
      expectedTrackingNumbers: {'1Z999AA10123456784': '1'},
    );
    expect(result.status, MatchStatus.autoMatched);
    expect(result.best!.customer.id, '1');
  });

  test('exact phone match scores 95 and auto-matches', () {
    final customers = [_customer(id: '1', name: 'Someone Else', phone: '(302) 555-0134')];
    final label = _label(phone: '302-555-0134');
    final result = service.match(label: label, customers: customers);
    expect(result.bestScore, 95);
    expect(result.status, MatchStatus.autoMatched);
  });

  test('exact email match scores 95', () {
    final customers = [_customer(id: '1', name: 'A B', email: 'test@example.com')];
    final label = _label(email: 'test@example.com');
    final result = service.match(label: label, customers: customers);
    expect(result.bestScore, 95);
  });

  test('exact address match (name+address) scores 90', () {
    final customers = [
      _customer(id: '1', name: 'John Smith', address: '123 Main Street'),
    ];
    final label = _label(recipientName: 'John Smith', addressLine1: '123 Main Street');
    final result = service.match(label: label, customers: customers);
    expect(result.bestScore, 90);
    expect(result.status, MatchStatus.autoMatched);
  });

  test('fuzzy name + exact address is a review-tier match (80), not auto', () {
    final customers = [
      _customer(id: '1', name: 'John Smith', address: '123 Main Street'),
    ];
    // OCR mangled the name slightly but the address is a perfect match.
    final label = _label(recipientName: 'Jon Smth', addressLine1: '123 Main Street');
    final result = service.match(label: label, customers: customers);
    expect(result.bestScore, 80);
    expect(result.status, MatchStatus.needsReview);
  });

  test('fuzzy name alone (nothing else corroborating) never exceeds 50 — '
      'must never auto-assign on a bare name guess', () {
    final customers = [_customer(id: '1', name: 'John Smith')];
    final label = _label(recipientName: 'Jon Smth');
    final result = service.match(label: label, customers: customers);
    expect(result.bestScore, lessThanOrEqualTo(50));
    expect(result.status, MatchStatus.unknown);
  });

  test('two customers with similar names: address is the tiebreaker, '
      'the wrong one never wins just for having a similar name', () {
    final customers = [
      _customer(id: '1', name: 'John Smith', address: '123 Main Street'),
      _customer(id: '2', name: 'Jon Smith', address: '999 Nowhere Ave'),
    ];
    final label = _label(recipientName: 'John Smith', addressLine1: '123 Main Street');
    final result = service.match(label: label, customers: customers);
    expect(result.best!.customer.id, '1');
    expect(result.bestScore, 90);
  });

  test('no signals at all → unmatched with an empty candidate list', () {
    final customers = [_customer(id: '1', name: 'Nobody Related')];
    final label = _label(recipientName: 'Totally Different Person');
    final result = service.match(label: label, customers: customers);
    expect(result.status, MatchStatus.unknown);
    expect(result.candidates, isEmpty);
  });

  test('empty customer list never crashes and always resolves unknown', () {
    final label = _label(recipientName: 'Anyone');
    final result = service.match(label: label, customers: const []);
    expect(result.status, MatchStatus.unknown);
    expect(result.best, isNull);
  });

  test('custom thresholds are respected', () {
    const strict = CustomerMatchService(autoMatchThreshold: 95, manualReviewThreshold: 85);
    final customers = [
      _customer(id: '1', name: 'John Smith', address: '123 Main Street'),
    ];
    // This scores 90 (address+name exact) — auto-matches under default
    // thresholds but should NOT under a stricter 95 threshold.
    final label = _label(recipientName: 'John Smith', addressLine1: '123 Main Street');
    final result = strict.match(label: label, customers: customers);
    expect(result.status, MatchStatus.needsReview);
  });
}
