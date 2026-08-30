part of '../pos_api_service.dart';

extension PosApiProductExtension on PosApiService {
  Future<String?> uploadProductImage({
    required int productId,
    required File imageFile,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final response = await _sendRequest(
        method: 'POST',
        path: '/api/v1/products/$productId/image',
        body: {'image': base64Encode(bytes)},
        timeout: const Duration(seconds: 30),
      );
      if (response is Map && response['url'] != null) {
        final baseUrl = await getBaseUrl();
        return '$baseUrl${response['url']}';
      }
    } catch (e) {
      debugPrint('❌ Upload product image error: $e');
    }
    return null;
  }

  // 2. Fetch Products
  Future<List<PosProduct>> getProducts({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final String path;
      final Map<String, String>? query;
      if (search != null && search.isNotEmpty) {
        path = '/api/v1/products/search';
        query = {'q': search};
      } else {
        path = '/api/v1/products';
        query = {
          'page': page.toString(),
          'limit': limit.toString(),
        };
      }

      final response = await _sendRequest(
        method: 'GET',
        path: path,
        query: query,
      );

      if (response == null || response is! List) return [];
      return response.map((json) => PosProduct.fromMap(json)).toList();
    } catch (e) {
      debugPrint('❌ Fetch Products Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> updateProduct(
      int id, Map<String, dynamic> data) async {
    final response = await _sendRequest(
      method: 'PUT',
      path: '/api/v1/products/$id',
      body: data,
    );
    return response as Map<String, dynamic>? ?? {};
  }

  // 6. Customer Management (Hybrid)
  Future<List<PosCustomer>> searchCustomers(String term) async {
    try {
      final response = await _sendRequest(
        method: 'GET',
        path: '/api/v1/customers/search',
        query: {'q': term},
      );
      if (response == null || response is! List) return [];
      return response.map((json) => PosCustomer.fromMap(json)).toList();
    } catch (e) {
      debugPrint('❌ API Search Customers Error: $e');
      return [];
    }
  }
}
