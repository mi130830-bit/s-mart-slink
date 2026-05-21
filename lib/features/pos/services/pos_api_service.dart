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

    // ✅ Fallback: Use Cloudflare Tunnel if not set
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      _baseUrl = 'https://api.namecheap.work'; // Hardcoded Fallback
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

    // Ensure path starts with /
    if (!path.startsWith('/')) path = '/$path';

    // Cloudflare Tunnel usually provides https
    String fullUrl = '$base$path';

    // Append Query Parameters
    if (query != null && query.isNotEmpty) {
      final queryString = Uri(queryParameters: query).query;
      fullUrl += '?$queryString';
    }

    return Uri.tryParse(fullUrl);
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
    try {
      final uri = await _buildUri('/api/v1$path');
      if (uri == null) throw Exception('Base URL not configured');

      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonBody,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return {'success': true};
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
            'POST $path failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ postRaw($path) Error: $e');
      rethrow;
    }
  }
}
