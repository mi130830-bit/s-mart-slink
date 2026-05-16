import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:s_link/features/pos/models/pos_product.dart';
import 'package:s_link/features/pos/models/pos_customer.dart';

class PosApiService {
  static final PosApiService _instance = PosApiService._internal();

  factory PosApiService() {
    return _instance;
  }

  PosApiService._internal();

  http.Client _client = http.Client();

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

  // 2. Fetch Products
  Future<List<PosProduct>> getProducts({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final query = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      // Note: Backend Search is typically a separate endpoint or query param
      // POS Backend uses /api/v1/products/search?q=... for searching
      // and /api/v1/products?page=... for listing.
      // We will handle this logic here.

      Uri? uri;
      if (search != null && search.isNotEmpty) {
        uri = await _buildUri('/api/v1/products/search', {'q': search});
      } else {
        uri = await _buildUri('/api/v1/products', query);
      }

      if (uri == null) throw Exception('Base URL not configured');

      final response =
          await _client.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (response.body.isEmpty || response.body == '[]') return [];
        try {
          final List<dynamic> data = jsonDecode(response.body);
          return data.map((json) => PosProduct.fromMap(json)).toList();
        } catch (e) {
          debugPrint('❌ API Parse Error: $e');
          debugPrint('📄 Raw Body: ${response.body}');
          return [];
        }
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Fetch Products Error: $e');
      return [];
    }
  }

  // 3. Create Order
  Future<Map<String, dynamic>> createOrder(
    Map<String, dynamic> orderData, {
    String? note,
  }) async {
    try {
      final uri = await _buildUri('/api/v1/orders');
      if (uri == null) throw Exception('Base URL not configured');

      if (note != null && note.isNotEmpty) {
        orderData['note'] = note;
      }

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(orderData),
      );

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return {}; // ✅ Fix: Handle empty response
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to create order: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating order: $e');
    }
  }

  // 4. Adjust Stock
  Future<Map<String, dynamic>> adjustStock({
    required int productId,
    required double newQuantity,
    String note = 'Remote Adjustment',
    String user = 'Remote User',
  }) async {
    try {
      final uri = await _buildUri('/api/v1/stock/adjust');
      if (uri == null) throw Exception('Base URL not configured');

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'productId': productId,
          'quantity': newQuantity,
          'note': note,
          'user': user,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to adjust stock: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error adjusting stock: $e');
    }
  }

  Future<Map<String, dynamic>> updateProduct(
      int id, Map<String, dynamic> data) async {
    try {
      final uri = await _buildUri('/api/v1/products/$id');
      if (uri == null) throw Exception('Base URL not configured');

      final response = await _client.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'Failed to update product: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error updating product: $e');
    }
  }

  // 5. Shortage / Stock Alert Management
  Future<List<Map<String, dynamic>>> getShortages() async {
    try {
      final uri = await _buildUri('/api/v1/shortages');
      if (uri == null) throw Exception('Base URL not configured');

      debugPrint('📡 GET Shortages URL: $uri');
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 10));

      debugPrint(
          '📡 Shortages Response [${response.statusCode}]: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty || response.body == '[]') return [];
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get shortages: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Get Shortages Error: $e');
      return [];
    }
  }

  Future<void> createShortage(String itemName, String reporterId) async {
    try {
      final uri = await _buildUri('/api/v1/shortages');
      if (uri == null) throw Exception('Base URL not configured');

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'itemName': itemName,
          'reporterId': reporterId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to create shortage: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating shortage: $e');
    }
  }

  Future<void> markShortageOrdered(dynamic id) async {
    try {
      final uri = await _buildUri('/api/v1/shortages/$id/order');
      if (uri == null) throw Exception('Base URL not configured');

      final response = await _client.put(uri);

      if (response.statusCode != 200) {
        throw Exception('Failed to mark ordered: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error marking ordered: $e');
    }
  }

  Future<void> deleteShortage(dynamic id) async {
    try {
      final uri = await _buildUri('/api/v1/shortages/$id');
      if (uri == null) throw Exception('Base URL not configured');

      final response = await _client.delete(uri);

      if (response.statusCode != 200) {
        throw Exception('Failed to delete shortage: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting shortage: $e');
    }
  }

  // 6. Customer Management (Hybrid)
  Future<List<PosCustomer>> searchCustomers(String term) async {
    try {
      final uri = await _buildUri('/api/v1/customers/search', {'q': term});
      if (uri == null) return [];

      final response =
          await _client.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (response.body.isEmpty || response.body == '[]') return [];
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => PosCustomer.fromMap(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ API Search Customers Error: $e');
      return [];
    }
  }

  // 7. Line Notification
  Future<bool> sendLineMessage(String lineUserId, String message) async {
    if (lineUserId.isEmpty) return false; // ✅ Guard: No Line ID
    try {
      // Use the Cloudflare Tunnel Base URL
      // POS Backend path is likely /api/line/push-message or just /line/push-message depending on router
      // From POS Desktop code: uri = Uri.parse('$apiUrl/line/push-message');
      // So path is /line/push-message. But PosApiService generic `_buildUri` might prepend /api/v1 if not careful.
      // `_buildUri` takes path literally.
      // Let's assume standard API prefix or try to use exact path if known.
      // Let's allow flexible path.

      // Try /api/v1/line/push-message first (standard)
      // If that fails, maybe we need a dedicated method.
      // For now, let's use '/line/push-message' (assuming base url is root).
      // Wait, PosApiService usually has base url like https://tunnel.com.
      // POS Desktop settings usually point to https://tunnel.com/api/v1 or similar?
      // No, usually just host.
      // Let's try '/line/push-message'.

      final url = await _buildUri('/line/push-message');

      if (url == null) return false;

      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lineUserId': lineUserId,
          'message': message,
        }),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('❌ API Send Line Failed: $e');
      return false;
    }
  }

  // 8. Increase Stock (Relative)
  Future<Map<String, dynamic>> increaseStock({
    required int productId,
    required double quantity,
    String note = 'Stock In via App',
    String user = 'App User',
  }) async {
    try {
      final uri = await _buildUri('/api/v1/stock/increase');
      if (uri == null) throw Exception('Base URL not configured');

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'productId': productId,
          'quantity': quantity,
          'note': note,
          'user': user,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to increase stock: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error increasing stock: $e');
    }
  }

  // 9. Pay COD Debt
  Future<bool> payCodDebt({
    required String jobId,
    required String customerId,
    required double amount,
    required String driverId,
    int? orderId,
  }) async {
    try {
      final uri = await _buildUri('/api/v1/debt/cod-payment');
      if (uri == null) throw Exception('Base URL not configured');

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jobId': jobId,
          'customerId': customerId,
          'amount': amount,
          'driverId': driverId,
          if (orderId != null) 'orderId': orderId,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        debugPrint(
            '❌ API COD Payment Failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ API COD Payment Error: $e');
      return false;
    }
  }

  // 10. Daily Sales Summary
  Future<Map<String, dynamic>?> getDailySummary() async {
    try {
      final uri = await _buildUri('/api/v1/orders/daily-summary');
      if (uri == null) throw Exception('Base URL not configured');

      final response =
          await _client.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return null;
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('❌ API getDailySummary Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ getDailySummary Error: $e');
      return null;
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

  // ✅ 12. ดึงประวัติงานส่งของ (delivery_history) จาก MySQL ผ่าน POS Backend API
  // แทนการดึงจาก Firebase ที่ถูกลบไปแล้วหลัง Archive
  Future<List<Map<String, dynamic>>> getDeliveryHistory({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final start = '${startDate.year.toString().padLeft(4, '0')}-'
          '${startDate.month.toString().padLeft(2, '0')}-'
          '${startDate.day.toString().padLeft(2, '0')}';
      final end = '${endDate.year.toString().padLeft(4, '0')}-'
          '${endDate.month.toString().padLeft(2, '0')}-'
          '${endDate.day.toString().padLeft(2, '0')}';

      final uri = await _buildUri('/api/v1/jobs/list', {
        'start': start,
        'end': end,
      });
      if (uri == null) return [];

      debugPrint('📡 [API] GET Delivery History: $uri');
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return [];
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'] as List<dynamic>? ?? [];
        debugPrint('✅ [API] Got ${data.length} history records');
        return data.cast<Map<String, dynamic>>();
      } else {
        debugPrint('❌ [API] getDeliveryHistory: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ [API] getDeliveryHistory Error: $e');
      return [];
    }
  }

  // ✅ 13. ดึงสถิติงานส่งของ (Stats) จาก MySQL ผ่าน POS Backend API
  // ใช้สำหรับหน้า Driver Stats ใน S-Link
  Future<Map<String, dynamic>?> getJobSummaryStats() async {
    try {
      final uri = await _buildUri('/api/v1/jobs/stats');
      if (uri == null) return null;

      debugPrint('📡 [API] GET Job Stats: $uri');
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return null;
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('❌ [API] getJobSummaryStats Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ [API] getJobSummaryStats Error: $e');
      return null;
    }
  }
}
