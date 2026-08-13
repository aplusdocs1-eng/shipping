import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:courierwarehousing/services/offline_scan_queue.dart';

void main() {
  group('generatePackageIdempotencyKey', () {
    test('is deterministic for the same tracking number', () {
      final a = generatePackageIdempotencyKey(trackingOrBarcode: '1Z999AA10123456784');
      final b = generatePackageIdempotencyKey(trackingOrBarcode: '1Z999AA10123456784');
      expect(a, b);
    });

    test('is case- and whitespace-insensitive — the same physical scan '
        'retried with slightly different OCR capitalization must still '
        'produce the same key', () {
      final a = generatePackageIdempotencyKey(trackingOrBarcode: '1z999aa10123456784');
      final b = generatePackageIdempotencyKey(trackingOrBarcode: ' 1Z999AA10123456784 ');
      expect(a, b);
    });

    test('different tracking numbers never collide', () {
      final a = generatePackageIdempotencyKey(trackingOrBarcode: '1Z999AA10123456784');
      final b = generatePackageIdempotencyKey(trackingOrBarcode: '1Z999AA10123456785');
      expect(a, isNot(b));
    });

    test('different warehouses scanning the same tracking number get '
        'different keys (multi-warehouse-safe)', () {
      final a = generatePackageIdempotencyKey(warehouseId: 'kingston', trackingOrBarcode: 'ABC123');
      final b = generatePackageIdempotencyKey(warehouseId: 'montego-bay', trackingOrBarcode: 'ABC123');
      expect(a, isNot(b));
    });
  });

  group('OfflineScanQueue', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('enqueue stores a payload that pendingCount reflects', () async {
      final queue = OfflineScanQueue();
      expect(await queue.pendingCount(), 0);
      await queue.enqueue({
        'trackingNumber': '1Z999AA10123456784',
        'idempotencyKey': generatePackageIdempotencyKey(trackingOrBarcode: '1Z999AA10123456784'),
      });
      expect(await queue.pendingCount(), 1);
    });

    test('multiple distinct scans queue independently', () async {
      final queue = OfflineScanQueue();
      await queue.enqueue({'trackingNumber': 'A'});
      await queue.enqueue({'trackingNumber': 'B'});
      await queue.enqueue({'trackingNumber': 'C'});
      expect(await queue.pendingCount(), 3);
    });
  });
}
