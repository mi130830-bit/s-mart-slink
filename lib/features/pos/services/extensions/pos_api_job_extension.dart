part of '../pos_api_service.dart';

extension PosApiJobExtension on PosApiService {
  // 3. Create Order
  Future<Map<String, dynamic>> createOrder(
    Map<String, dynamic> orderData, {
    String? note,
  }) async {
    if (note != null && note.isNotEmpty) {
      orderData['note'] = note;
    }
    final response = await _sendRequest(
      method: 'POST',
      path: '/api/v1/orders',
      body: orderData,
    );
    return response as Map<String, dynamic>? ?? {};
  }

  // 10. Daily Sales Summary
  Future<Map<String, dynamic>?> getDailySummary() async {
    try {
      return await getDailySummaryRaw();
    } catch (e) {
      debugPrint('❌ getDailySummary Error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDailySummaryRaw() async {
    final response = await _sendRequest(
      method: 'GET',
      path: '/api/v1/orders/daily-summary',
    );
    return response as Map<String, dynamic>?;
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
      await _sendRequest(
        method: 'POST',
        path: '/api/v1/debt/cod-payment',
        body: {
          'jobId': jobId,
          'customerId': customerId,
          'amount': amount,
          'driverId': driverId,
          if (orderId != null) 'orderId': orderId,
        },
      );
      return true;
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

      final response = await _sendRequest(
        method: 'GET',
        path: '/api/v1/jobs/list',
        query: {
          'start': start,
          'end': end,
        },
      );
      if (response == null) return [];
      final decoded = response as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>? ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ [API] getDeliveryHistory Error: $e');
      return [];
    }
  }

  // ✅ 13. ดึงสถิติงานส่งของ (Stats) จาก MySQL ผ่าน POS Backend API
  Future<Map<String, dynamic>?> getJobSummaryStats() async {
    try {
      final response = await _sendRequest(
        method: 'GET',
        path: '/api/v1/jobs/stats',
      );
      return response as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('❌ [API] getJobSummaryStats Error: $e');
      return null;
    }
  }

  // ✅ [M2] 14. ดึงงานที่ยัง PENDING ทั้งหมดจาก MySQL (สำหรับ Offline Cache)
  // รองรับ since= เพื่อทำ Delta Sync (โหลดเฉพาะงานใหม่)
  Future<List<Map<String, dynamic>>> getActiveJobs({String? since}) async {
    try {
      final Map<String, String> query = {};
      if (since != null && since.isNotEmpty) {
        query['since'] = since;
      }
      final response = await _sendRequest(
        method: 'GET',
        path: '/api/v1/jobs/active',
        query: query.isNotEmpty ? query : null,
      );
      if (response == null) return [];
      final decoded = response as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>? ?? [];
      debugPrint('✅ [API] getActiveJobs: ${data.length} active jobs fetched');
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ [API] getActiveJobs Error: $e');
      return [];
    }
  }
}

