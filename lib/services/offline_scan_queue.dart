import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

/// warehouse_id + tracking/barcode value — the idempotency key every
/// package-scan submission carries (see the migration's unique index on
/// warehouse_entries.idempotency_key and process-package-scan's
/// idempotent-replay short-circuit). Deterministic and stable no matter
/// how many times the same physical scan gets retried or resynced.
///
/// This deployment doesn't have a populated multi-warehouse/branch
/// concept in practice (a real `warehouse_id` would come from `branches`,
/// which exists but is empty) — 'main' is used as a stable placeholder so
/// the key shape is still future-proof if that changes.
String generatePackageIdempotencyKey({
  String warehouseId = 'main',
  required String trackingOrBarcode,
}) {
  final normalized = trackingOrBarcode.trim().toUpperCase();
  return '$warehouseId::$normalized';
}

/// Warehouse Wi-Fi is unreliable — this queues a scan submission locally
/// (shared_preferences; already a dependency, no new storage mechanism
/// needed) whenever the network is down or a submission fails, and
/// retries automatically once connectivity returns. Every queued payload
/// already carries its idempotency key, so a scan that actually made it
/// to the server before the connection dropped is never double-created
/// when the retry goes through — process-package-scan's idempotent-replay
/// check is what actually guarantees that; this queue's job is only to
/// not lose the scan and to eventually retry it.
class OfflineScanQueue {
  OfflineScanQueue._();
  static final OfflineScanQueue _instance = OfflineScanQueue._();
  factory OfflineScanQueue() => _instance;

  static const _prefsKey = 'offline_scan_queue_v1';
  final _db = DatabaseService();
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final _statusController = StreamController<OfflineSyncStatus>.broadcast();
  Stream<OfflineSyncStatus> get statusStream => _statusController.stream;
  bool _syncing = false;

  void startWatching() {
    _sub ??= _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) syncAll();
    });
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  Future<List<Map<String, dynamic>>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeAll(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(items));
  }

  Future<int> pendingCount() async => (await _readAll()).length;

  /// Called when a scan can't reach the server right now (offline, or the
  /// request itself failed) — stores the exact payload that would have
  /// been sent to processPackageScan, to be replayed later.
  Future<void> enqueue(Map<String, dynamic> payload) async {
    final items = await _readAll();
    items.add(payload);
    await _writeAll(items);
  }

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> syncAll() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final items = await _readAll();
      if (items.isEmpty) return;
      var completed = 0;
      _statusController.add(OfflineSyncStatus(total: items.length, completed: 0, syncing: true));
      final remaining = <Map<String, dynamic>>[];
      for (final payload in items) {
        try {
          await _db.processPackageScan(payload);
          completed++;
          _statusController.add(
            OfflineSyncStatus(total: items.length, completed: completed, syncing: true),
          );
        } catch (_) {
          // Still offline, or a transient server error — keep it queued
          // and try again on the next connectivity change.
          remaining.add(payload);
        }
      }
      await _writeAll(remaining);
      _statusController.add(
        OfflineSyncStatus(total: items.length, completed: completed, syncing: false),
      );
    } finally {
      _syncing = false;
    }
  }
}

class OfflineSyncStatus {
  final int total;
  final int completed;
  final bool syncing;
  const OfflineSyncStatus({required this.total, required this.completed, required this.syncing});
}
