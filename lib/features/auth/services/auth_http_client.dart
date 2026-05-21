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
          request.headers['Authorization'] = 'Bearer $token';
        }
      }
    } catch (e) {
      debugPrint('⚠️ AuthHttpClient Error fetching token: $e');
    }

    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
