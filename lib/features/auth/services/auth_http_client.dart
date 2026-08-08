import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Interceptor สำหรับแนบ Custom JWT Token ไปกับ Header (Authorization: Bearer [token]) โดยอัตโนมัติ
class AuthHttpClient extends http.BaseClient {
  final http.Client _inner;
  static Future<String?>? _refreshInProgress;

  AuthHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final retryRequest = _copyRequest(request);
    try {
      final prefs = await SharedPreferences.getInstance();
      var token = prefs.getString('jwt_token');
      if (_isExpiredOrExpiring(token) && !_isAuthEndpoint(request.url)) {
        token = await _refreshAccessToken(request.url, prefs);
      }

      if (token != null && token.isNotEmpty) {
        debugPrint(
            '🔑 AuthHttpClient: Token obtained, length: ${token.length}');
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

    final response = await _inner.send(request);
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        retryRequest != null &&
        !_isAuthEndpoint(request.url)) {
      final prefs = await SharedPreferences.getInstance();
      final token = await _refreshAccessToken(request.url, prefs, force: true);
      if (token != null) {
        // The original response is discarded only when a retry will replace
        // it. Draining it unconditionally leaves BaseClient with a stream
        // that it cannot convert into http.Response.
        await response.stream.drain<void>();
        retryRequest.headers['Authorization'] = 'Bearer $token';
        debugPrint('🔄 AuthHttpClient: Token refreshed; retrying once.');
        return _inner.send(retryRequest);
      }
    }
    return response;
  }

  bool _isAuthEndpoint(Uri uri) => uri.path.contains('/api/v1/auth/');

  bool _isExpiredOrExpiring(String? token) {
    if (token == null || token.isEmpty) return true;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = (payload['exp'] as num?)?.toInt();
      if (exp == null) return true;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return exp <= now + 60;
    } catch (_) {
      return true;
    }
  }

  Future<String?> _refreshAccessToken(
    Uri requestUri,
    SharedPreferences prefs, {
    bool force = false,
  }) async {
    if (!force) {
      final current = prefs.getString('jwt_token');
      if (!_isExpiredOrExpiring(current)) return current;
    }
    final existing = _refreshInProgress;
    if (existing != null) return existing;

    final future = _performRefresh(requestUri, prefs);
    _refreshInProgress = future;
    try {
      return await future;
    } finally {
      _refreshInProgress = null;
    }
  }

  Future<String?> _performRefresh(
    Uri requestUri,
    SharedPreferences prefs,
  ) async {
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) {
      return _loginWithStoredCredentials(requestUri, prefs);
    }
    final refreshUri = requestUri.replace(
      path: '/api/v1/auth/refresh',
      query: null,
      fragment: null,
    );
    try {
      final response = await _inner.post(
        refreshUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await prefs.remove('jwt_token');
        await prefs.remove('refresh_token');
        return _loginWithStoredCredentials(requestUri, prefs);
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token']?.toString();
      if (token == null || token.isEmpty) return null;
      await prefs.setString('jwt_token', token);
      return token;
    } catch (e) {
      debugPrint('⚠️ AuthHttpClient: Token refresh failed: $e');
      return null;
    }
  }

  /// Restores the POS session for legacy/Firebase-only app sessions that have
  /// cached offline credentials but no JWT or refresh token yet. This uses the
  /// existing local offline-login credentials and never sends a protected API
  /// request without first attempting POS authentication.
  Future<String?> _loginWithStoredCredentials(
    Uri requestUri,
    SharedPreferences prefs,
  ) async {
    final username = prefs.getString('offline_username');
    final password = prefs.getString('offline_password');
    if (username == null || username.isEmpty || password == null) return null;

    final loginUri = requestUri.replace(
      path: '/api/v1/auth/login',
      query: null,
      fragment: null,
    );
    try {
      final response = await _inner.post(
        loginUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('⚠️ AuthHttpClient: Stored-credential login failed.');
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token']?.toString();
      if (token == null || token.isEmpty) return null;
      await prefs.setString('jwt_token', token);
      await prefs.setString('offline_jwt_token', token);
      final refreshToken = data['refresh_token']?.toString();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await prefs.setString('refresh_token', refreshToken);
      }
      debugPrint('✅ AuthHttpClient: POS session restored automatically.');
      return token;
    } catch (e) {
      debugPrint('⚠️ AuthHttpClient: Stored-credential login failed: $e');
      return null;
    }
  }

  http.Request? _copyRequest(http.BaseRequest request) {
    if (request is! http.Request) return null;
    final copy = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes
      ..encoding = request.encoding
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection;
    return copy;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
