part of '../pos_api_service.dart';

extension PosApiLineExtension on PosApiService {
  // 7. Line Notification
  Future<bool> sendLineMessage(String lineUserId, String message) async {
    if (lineUserId.isEmpty) return false; // ✅ Guard: No Line ID
    try {
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
}
