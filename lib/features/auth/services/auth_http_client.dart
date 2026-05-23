import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Interceptor สำหรับแนบ Firebase ID Token ไปกับ Header (Authorization: Bearer [token]) โดยอัตโนมัติ
class AuthHttpClient extends http.BaseClient {
  final http.Client _inner;

  AuthHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // ดึง Token ปัจจุบัน (ถ้าหมดอายุ Firebase จะ Refresh ให้อัตโนมัติโดยเบื้องหลัง)
        final token = await user.getIdToken();
        if (token != null) {
          debugPrint('🔑 AuthHttpClient: Token obtained, length: ${token.length}');
          request.headers['Authorization'] = 'Bearer $token';
        } else {
          debugPrint('❌ AuthHttpClient: Token is null!');
        }
      } else {
        debugPrint('❌ AuthHttpClient: User is null!');
      }
    } catch (e) {
      debugPrint('⚠️ AuthHttpClient Error fetching token: $e');
    }

    debugPrint('🌐 HTTP Request: ${request.method} ${request.url}');
    if (!request.headers.containsKey('Authorization')) {
      debugPrint('🚨 WARNING: Request sent WITHOUT Authorization header!');
    }

    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
