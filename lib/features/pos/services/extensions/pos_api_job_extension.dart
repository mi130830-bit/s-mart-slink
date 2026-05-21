part of '../pos_api_service.dart';

extension PosApiJobExtension on PosApiService {
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

  // ✅ 12. ดึงประวัติงานส่งของ (delivery_history) จาก MySQL ผ่าน POS Backend API
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
