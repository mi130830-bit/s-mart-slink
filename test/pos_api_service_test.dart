import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart'; // http package often includes this or we use MockClient
import 'package:s_link/features/pos/services/pos_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PosApiService Text', () {
    late PosApiService service;
    late MockClient mockClient;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'pos_api_base_url': 'https://api.example.com',
      });
      service = PosApiService();
    });

    // STAGE 1: Order Received
    test('Stage 1: Send "Order Received" Notification', () async {
      final lineUserId = 'U_STAGE_1';
      final msg = '🛒 ร้าน ส.บริการ ... ได้รับรายการสั่งซื้อแล้ว';

      mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        if (body['lineUserId'] == lineUserId && body['message'] == msg) {
          return http.Response('{"success": true}', 200);
        }
        return http.Response('Error', 400);
      });

      service.setClient(mockClient);
      final result = await service.sendLineMessage(lineUserId, msg);
      expect(result, true);
    });

    // STAGE 2: Out for Delivery
    test('Stage 2: Send "Out for Delivery" Notification', () async {
      final lineUserId = 'U_STAGE_2';
      final msg = '🚚 สินค้าของท่านกำลังเดินทาง...';

      mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        if (body['lineUserId'] == lineUserId && body['message'] == msg) {
          return http.Response('{"success": true}', 200);
        }
        return http.Response('Error', 400);
      });

      service.setClient(mockClient);
      final result = await service.sendLineMessage(lineUserId, msg);
      expect(result, true);
    });

    // STAGE 3: Delivered
    test('Stage 3: Send "Delivered" Notification', () async {
      final lineUserId = 'U_STAGE_3';
      final msg = '✅ ส่งสินค้าเรียบร้อยแล้ว';

      mockClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        if (body['lineUserId'] == lineUserId && body['message'] == msg) {
          return http.Response('{"success": true}', 200);
        }
        return http.Response('Error', 400);
      });

      service.setClient(mockClient);
      final result = await service.sendLineMessage(lineUserId, msg);
      expect(result, true);
    });

    // STAGE 4: Handle Missing Line ID
    test('Stage 4: Handle Missing Line User ID (Should not send)', () async {
      final lineUserId = ''; // Empty
      final msg = 'Hello';

      mockClient = MockClient((request) async {
        // Should NOT be called
        return http.Response('Should not be called', 500);
      });

      service.setClient(mockClient);
      final result = await service.sendLineMessage(lineUserId, msg);
      expect(result, false); // Expect false
    });

    test('updateProduct sends correct PUT request', () async {
      mockClient = MockClient((request) async {
        if (request.method == 'PUT' &&
            request.url.path == '/api/v1/products/123') {
          return http.Response('{"id": 123, "name": "New Name"}', 200);
        }
        return http.Response('Error', 400);
      });

      service.setClient(mockClient);

      final result = await service.updateProduct(123, {'name': 'New Name'});
      expect(result['name'], 'New Name');
    });
  });
}
