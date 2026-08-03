import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Interceptor สำหรับแนบ Custom JWT Token ไปกับ Header (Authorization: Bearer [token]) โดยอัตโนมัติ
class AuthHttpClient extends http.BaseClient {
  final http.Client _inner;

  AuthHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      
      if (token != null && token.isNotEmpty) {
        debugPrint('🔑 AuthHttpClient: Token obtained, length: ${token.length}');
        request.headers['Authorization'] = 'Bearer $token';
      } else {
        debugPrint('❌ AuthHttpClient: Token is null or empty!');
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
