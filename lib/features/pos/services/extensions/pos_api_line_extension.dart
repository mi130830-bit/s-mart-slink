part of '../pos_api_service.dart';

extension PosApiLineExtension on PosApiService {
  // 7. Line Notification
  Future<bool> sendLineMessage(String lineUserId, String message) async {
    if (lineUserId.isEmpty) return false;
    try {
      await _sendRequest(
        method: 'POST',
        path: '/line/push-message',
        body: {
          'lineUserId': lineUserId,
          'message': message,
        },
      );
      return true;
    } catch (e) {
      debugPrint('❌ API Send Line Failed: $e');
      return false;
    }
  }
}
