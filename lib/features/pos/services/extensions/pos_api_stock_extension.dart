part of '../pos_api_service.dart';

extension PosApiStockExtension on PosApiService {
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
}
