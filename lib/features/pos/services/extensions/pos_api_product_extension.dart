part of '../pos_api_service.dart';

extension PosApiProductExtension on PosApiService {
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
}
