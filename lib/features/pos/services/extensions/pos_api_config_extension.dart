part of '../pos_api_service.dart';

extension PosApiConfigExtension on PosApiService {
  Future<dynamic> getStockCheckTemplate() =>
      _sendRequest(method: 'GET', path: '/api/v1/config/stock-check-template');
  Future<dynamic> saveStockCheckTemplate(
          int revision, List<Map<String, dynamic>> items) =>
      _sendRequest(
          method: 'POST',
          path: '/api/v1/config/stock-check-template',
          body: {'expected_revision': revision, 'items': items});
}
