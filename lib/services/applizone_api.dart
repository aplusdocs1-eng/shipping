import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service that connects to the Applizone Central JA backoffice API.
/// Third-party shipping companies authenticate through this service
/// so scanned warehouse packages can be logged to their database.
class ApplizoneApi {
  static const String _baseUrl = 'https://applizonecentralja.com';
  static const String _tokenKey = 'applizone_token';
  static const String _emailKey = 'applizone_email';
  static const String _companyKey = 'applizone_company';

  static final ApplizoneApi _instance = ApplizoneApi._internal();
  factory ApplizoneApi() => _instance;
  ApplizoneApi._internal();

  String? _token;
  String? _email;
  String? _companyName;
  bool _connected = false;

  bool get isConnected => _connected;
  String? get email => _email;
  String? get companyName => _companyName;

  // ─── Initialise from saved session ───────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _email = prefs.getString(_emailKey);
    _companyName = prefs.getString(_companyKey);
    _connected = _token != null && _token!.isNotEmpty;
  }

  // ─── Authenticate against Applizone backoffice ───────────────────────────

  Future<ApplizoneLoginResult> login(String email, String password) async {
    try {
      // First, get the login page to pick up any CSRF / session cookies
      final client = http.Client();
      try {
        final loginPageRes = await client.get(
          Uri.parse('$_baseUrl/auth/back/login'),
        );

        // Extract cookies from the initial page load
        final cookies = loginPageRes.headers['set-cookie'] ?? '';

        // Attempt authentication
        final loginRes = await client.post(
          Uri.parse('$_baseUrl/auth/back/login'),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Cookie': cookies,
            'Referer': '$_baseUrl/auth/back/login',
          },
          body: {'email': email, 'password': password},
        );

        // If we get a redirect to /backoffice, login was successful
        if (loginRes.statusCode == 200 ||
            loginRes.statusCode == 302 ||
            loginRes.statusCode == 303) {
          final responseCookies = loginRes.headers['set-cookie'] ?? '';
          final allCookies = cookies.isNotEmpty
              ? '$cookies; $responseCookies'
              : responseCookies;

          if (loginRes.statusCode == 302 || loginRes.statusCode == 303) {
            // Redirect means success
            _token = allCookies;
            _email = email;
            _companyName = _extractCompanyFromEmail(email);
            _connected = true;
            await _saveSession();
            return ApplizoneLoginResult(success: true);
          }

          // Check if the response body indicates success
          final body = loginRes.body.toLowerCase();
          if (body.contains('backoffice') || body.contains('dashboard')) {
            _token = allCookies;
            _email = email;
            _companyName = _extractCompanyFromEmail(email);
            _connected = true;
            await _saveSession();
            return ApplizoneLoginResult(success: true);
          }

          if (body.contains('invalid') ||
              body.contains('error') ||
              body.contains('incorrect')) {
            return ApplizoneLoginResult(
              success: false,
              error: 'Invalid email or password',
            );
          }

          // Assume success if we got a 200 without clear error
          _token = allCookies;
          _email = email;
          _companyName = _extractCompanyFromEmail(email);
          _connected = true;
          await _saveSession();
          return ApplizoneLoginResult(success: true);
        }

        return ApplizoneLoginResult(
          success: false,
          error: 'Authentication failed (${loginRes.statusCode})',
        );
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Applizone login error: $e');
      return ApplizoneLoginResult(
        success: false,
        error: 'Connection failed: ${e.toString()}',
      );
    }
  }

  // ─── Log a scanned package to the partner's database ─────────────────────

  Future<PackageSyncResult> syncPackage({
    required String trackingNumber,
    required String description,
    required double weight,
    required String customerName,
    String? storageLocation,
    String? shippingCompanyCode,
  }) async {
    if (!_connected || _token == null) {
      return PackageSyncResult(
        success: false,
        error: 'Not connected to Applizone',
      );
    }

    try {
      final payload = {
        'tracking_number': trackingNumber,
        'description': description,
        'weight': weight,
        'customer_name': customerName,
        'storage_location': storageLocation ?? '',
        'shipping_company_code': shippingCompanyCode ?? '',
        'scanned_at': DateTime.now().toIso8601String(),
        'source': 'warehouse_app',
      };

      final res = await http.post(
        Uri.parse('$_baseUrl/api/v1/packages/scan'),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': _token!,
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return PackageSyncResult(
          success: true,
          remoteId: data['id']?.toString(),
        );
      }

      return PackageSyncResult(
        success: false,
        error: 'Sync failed (${res.statusCode})',
      );
    } catch (e) {
      debugPrint('Applizone package sync error: $e');
      return PackageSyncResult(
        success: false,
        error: 'Sync error: ${e.toString()}',
      );
    }
  }

  // ─── Disconnect / Logout ─────────────────────────────────────────────────

  Future<void> disconnect() async {
    _token = null;
    _email = null;
    _companyName = null;
    _connected = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_companyKey);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _extractCompanyFromEmail(String email) {
    final domain = email.split('@').last;
    final name = domain.split('.').first;
    // Capitalise first letter of each word
    return name.replaceAllMapped(
      RegExp(r'(^|[^a-zA-Z])([a-z])'),
      (m) => '${m.group(1)}${m.group(2)!.toUpperCase()}',
    );
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString(_tokenKey, _token!);
    if (_email != null) await prefs.setString(_emailKey, _email!);
    if (_companyName != null) await prefs.setString(_companyKey, _companyName!);
  }
}

// ─── Result types ────────────────────────────────────────────────────────────

class ApplizoneLoginResult {
  final bool success;
  final String? error;
  ApplizoneLoginResult({required this.success, this.error});
}

class PackageSyncResult {
  final bool success;
  final String? remoteId;
  final String? error;
  PackageSyncResult({required this.success, this.remoteId, this.error});
}
