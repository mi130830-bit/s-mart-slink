import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:s_link/features/pos/models/pos_product.dart';
import 'package:s_link/features/pos/models/pos_customer.dart';
import 'package:s_link/features/auth/services/auth_http_client.dart';

part 'extensions/pos_api_product_extension.dart';
part 'extensions/pos_api_stock_extension.dart';
part 'extensions/pos_api_job_extension.dart';
part 'extensions/pos_api_line_extension.dart';

class PosApiService {
  static final PosApiService _instance = PosApiService._internal();

  factory PosApiService() {
    return _instance;
  }

  PosApiService._internal();

  http.Client _client = AuthHttpClient(http.Client());

  @visibleForTesting
  void setClient(http.Client client) {
    _client = client;
  }

  static const String _prefKeyBaseUrl = 'pos_api_base_url';
  String? _baseUrl;

  // Get Base URL (e.g., https://api.myshop.com)
  Future<String?> getBaseUrl() async {
    if (_baseUrl != null) return _baseUrl;
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_prefKeyBaseUrl);

    // ✅ Fallback: Use Local mDNS if not set
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      _baseUrl = 'http://POS-SERVER.local:8080'; // Local Network Fallback
      debugPrint('⚠️ Base URL not found. Using Fallback: $_baseUrl');
    }

    return _baseUrl;
  }

  // Set Base URL
  Future<void> setBaseUrl(String url) async {
    // Remove trailing slash if present
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyBaseUrl, url);
    _baseUrl = url;
  }

  // Helper: Build Full URL
  Future<Uri?> _buildUri(String path, [Map<String, String>? query]) async {
    final base = await getBaseUrl();
    if (base == null || base.isEmpty) return null;

    // Resolve mDNS / Hostname to IP if needed
    String resolvedBase = base;
    try {
      final uri = Uri.parse(base);
      if (uri.host.isNotEmpty && !RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(uri.host)) {
        String hostToResolve = uri.host;
        
        // 🚨 CRITICAL FIX: Only resolve manually if it's a .local domain or a single-word hostname.
        // Public domains (like .work, .com) MUST be resolved by http.Client natively to preserve SNI (Server Name Indication) for HTTPS (Cloudflare).
        if (!hostToResolve.contains('.') || hostToResolve.endsWith('.local')) {
          List<InternetAddress> ips = [];
          try {
            ips = await InternetAddress.lookup(hostToResolve);
          } catch (_) {
            if (!hostToResolve.contains('.')) {
              ips = await InternetAddress.lookup('$hostToResolve.local');
            }
          }

          if (ips.isNotEmpty) {
            final ip = ips.firstWhere((i) => i.type == InternetAddressType.IPv4, orElse: () => ips.first).address;
            resolvedBase = uri.replace(host: ip).toString();
            debugPrint('🔍 [DNS] Resolved Local API "$base" -> "$resolvedBase"');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [DNS] API Host Resolution Error: $e');
    }

    // Ensure path starts with /
    if (!path.startsWith('/')) path = '/$path';

    String fullUrl = '$resolvedBase$path';

    // Append Query Parameters
    if (query != null && query.isNotEmpty) {
      final queryString = Uri(queryParameters: query).query;
      fullUrl += '?$queryString';
    }

    return Uri.tryParse(fullUrl);
  }

  // Helper method to dispatch HTTP requests
  Future<dynamic> _sendRequest({
    required String method,
    required String path,
    Map<String, String>? query,
    dynamic body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final uri = await _buildUri(path, query);
      if (uri == null) throw Exception('Base URL not configured');
      final headers = <String, String>{
        if (body != null) 'Content-Type': 'application/json',
      };
      http.Response response;
      final bodyStr = body is String ? body : (body != null ? jsonEncode(body) : null);
      
      if (method == 'GET') {
        response = await _client.get(uri, headers: headers).timeout(timeout);
      } else if (method == 'POST') {
        response = await _client.post(uri, headers: headers, body: bodyStr).timeout(timeout);
      } else if (method == 'PUT') {
        response = await _client.put(uri, headers: headers, body: bodyStr).timeout(timeout);
      } else if (method == 'DELETE') {
        response = await _client.delete(uri, headers: headers).timeout(timeout);
      } else {
        throw Exception('Unsupported HTTP method: $method');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
        return jsonDecode(response.body);
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ API Error [$method $path]: $e');
      rethrow;
    }
  }

  // 1. Test Connection
  Future<bool> testConnection() async {
    try {
      final uri = await _buildUri('/api/v1/health');
      if (uri == null) return false;

      final response =
          await _client.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return true;
      }
      debugPrint('❌ API Test Failed: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ API Connection Error: $e');
      return false;
    }
  }

  // ✅ 11. Generic Raw POST — ส่ง JSON body ไปยัง path ใดก็ได้
  // ใช้โดย JobProvider สำหรับ POST /api/v1/jobs/complete
  Future<Map<String, dynamic>> postRaw(String path, String jsonBody) async {
    final response = await _sendRequest(
      method: 'POST',
      path: '/api/v1$path',
      body: jsonBody,
    );
    if (response == null) return {'success': true};
    return response as Map<String, dynamic>;
  }
}
