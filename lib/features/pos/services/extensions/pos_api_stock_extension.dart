part of '../pos_api_service.dart';

extension PosApiStockExtension on PosApiService {
  // 4. Adjust Stock
  Future<Map<String, dynamic>> adjustStock({
    required int productId,
    required double newQuantity,
    String note = 'Remote Adjustment',
    String user = 'Remote User',
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      path: '/api/v1/stock/adjust',
      body: {
        'productId': productId,
        'quantity': newQuantity,
        'note': note,
        'user': user,
      },
    );
    return response as Map<String, dynamic>? ?? {};
  }

  // 8. Increase Stock (Relative)
  Future<Map<String, dynamic>> increaseStock({
    required int productId,
    required double quantity,
    String note = 'Stock In via App',
    String user = 'App User',
  }) async {
    final response = await _sendRequest(
      method: 'POST',
      path: '/api/v1/stock/increase',
      body: {
        'productId': productId,
        'quantity': quantity,
        'note': note,
        'user': user,
      },
    );
    return response as Map<String, dynamic>? ?? {};
  }

  // 5. Shortage / Stock Alert Management
  Future<List<Map<String, dynamic>>> getShortages() async {
    try {
      final response = await _sendRequest(
        method: 'GET',
        path: '/api/v1/shortages',
      );
      if (response == null || response is! List) return [];
      return response.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ Get Shortages Error: $e');
      return [];
    }
  }

  Future<void> createShortage(String itemName, String reporterId) async {
    await _sendRequest(
      method: 'POST',
      path: '/api/v1/shortages',
      body: {
        'itemName': itemName,
        'reporterId': reporterId,
      },
    );
  }

  Future<void> markShortageOrdered(dynamic id) async {
    await _sendRequest(
      method: 'PUT',
      path: '/api/v1/shortages/$id/order',
    );
  }

  Future<void> deleteShortage(dynamic id) async {
    await _sendRequest(
      method: 'DELETE',
      path: '/api/v1/shortages/$id',
    );
  }
}
