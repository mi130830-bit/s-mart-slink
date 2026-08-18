part of '../pos_api_service.dart';

extension PosApiSupplierExtension on PosApiService {
  Future<List<Map<String, dynamic>>> getSuppliers({String search = ''}) async {
    final response = await _sendRequest(
      method: 'GET',
      path: '/api/v1/suppliers',
      query: {'q': search, 'limit': '100'},
    );
    if (response is! List) return [];
    return response
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
