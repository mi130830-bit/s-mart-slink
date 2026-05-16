import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MySQLService {
  static final MySQLService _instance = MySQLService._internal();

  factory MySQLService() {
    return _instance;
  }

  MySQLService._internal();

  MySQLConnection? _conn;
  bool _isConnecting = false;
  Completer<void>? _connectionCompleter;

  // Default settings
  static const String _defaultHost = '192.168.1.133'; // Static IP POS
  static const int _defaultPort = 3306;
  static const String _defaultUser = 'admin';
  static const String _defaultPass = '1234';
  static const String _defaultDb = 'sorborikan';

  Future<void> connect() async {
    if (isConnected()) return;
    if (_isConnecting) return _connectionCompleter?.future;

    _isConnecting = true;
    _connectionCompleter = Completer<void>();

    try {
      final prefs = await SharedPreferences.getInstance();
      final String host = prefs.getString('db_host') ?? _defaultHost;
      final int port = prefs.getInt('db_port') ?? _defaultPort;
      final String user = prefs.getString('db_user') ?? _defaultUser;
      final String pass = prefs.getString('db_pass') ?? _defaultPass;
      final String db = prefs.getString('db_name') ?? _defaultDb;

      // Resolve Hostname
      String resolvedHost = await _resolveHost(host);

      debugPrint(
          '🔌 [MySQL] Connecting to $resolvedHost ($host):$port (User: $user, DB: $db)...');

      _conn = await MySQLConnection.createConnection(
        host: resolvedHost,
        port: port,
        userName: user,
        password: pass,
        databaseName: db,
        secure: false,
      );

      await _conn!.connect();

      if (_conn!.connected) {
        debugPrint('✅ [MySQL] Connected successfully.');
        _connectionCompleter?.complete();
      } else {
        throw Exception('Connection established but not valid.');
      }
    } catch (e) {
      debugPrint('❌ [MySQL] Connection Error: $e');
      _connectionCompleter?.completeError(e);
      rethrow;
    } finally {
      _isConnecting = false;
      _connectionCompleter = null;
    }
  }

  bool isConnected() => _conn != null && _conn!.connected;

  Future<void> disconnect() async {
    if (_conn != null) {
      try {
        await _conn!.close();
      } catch (e) {
        debugPrint('⚠️ Error closing connection: $e');
      }
      _conn = null;
    }
  }

  // Helper to resolve IP
  Future<String> _resolveHost(String host) async {
    // If it's already an IP, return as is
    if (RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(host) ||
        host == 'localhost') {
      return host;
    }
    try {
      final List<InternetAddress> ips = await InternetAddress.lookup(host);
      if (ips.isNotEmpty) {
        // เลือก IPv4 ก่อนเพื่อความเสถียรในการเชื่อมต่อ MySQL
        final ip = ips
            .firstWhere((i) => i.type == InternetAddressType.IPv4,
                orElse: () => ips.first)
            .address;
        debugPrint('🔍 [DNS] Resolved "$host" -> $ip');
        return ip;
      }
    } catch (e) {
      debugPrint('⚠️ [DNS] Failed to resolve "$host": $e');

      // Fallback: ลองเติม .local (mDNS) หากชื่อเครื่องไม่มีจุด (เช่น "server-pc")
      if (!host.contains('.')) {
        debugPrint('🔄 [DNS] Retrying with .local suffix...');
        return _resolveHost('$host.local');
      }
    }
    return host; // Return original if fail
  }

  Future<String?> testConnection({
    required String host,
    required int port,
    required String user,
    required String pass,
    required String db,
  }) async {
    MySQLConnection? testConn;
    try {
      // Resolve Host for Test
      String resolvedHost = await _resolveHost(host);

      testConn = await MySQLConnection.createConnection(
        host: resolvedHost,
        port: port,
        userName: user,
        password: pass,
        databaseName: db,
        secure: false,
      );
      await testConn.connect();
      await testConn.close();
      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  Future<IResultSet> execute(String sql, [Map<String, dynamic>? params]) async {
    if (!isConnected()) await connect();
    try {
      return await _conn!
          .execute(sql, params)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('❌ SQL Execute Error: $e');
      // Auto-reconnect once
      if (e.toString().contains('closed') ||
          e.toString().contains('Broken pipe')) {
        await connect();
        return await _conn!.execute(sql, params);
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> query(String sql,
      [Map<String, dynamic>? params]) async {
    if (!isConnected()) await connect();
    try {
      final results = await _conn!
          .execute(sql, params)
          .timeout(const Duration(seconds: 10));
      return results.rows.map((row) => row.assoc()).toList();
    } catch (e) {
      debugPrint('❌ SQL Query Error: $e');
      if (e.toString().contains('closed') ||
          e.toString().contains('Broken pipe')) {
        await connect();
        final retry = await _conn!.execute(sql, params);
        return retry.rows.map((row) => row.assoc()).toList();
      }
      rethrow;
    }
  }

  Future<void> saveConfig({
    required String host,
    required int port,
    required String user,
    required String pass,
    required String db,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('db_host', host);
    await prefs.setInt('db_port', port);
    await prefs.setString('db_user', user);
    await prefs.setString('db_pass', pass);
    await prefs.setString('db_name', db);
    await disconnect(); // Force reconnect with new settings next time
  }
}
