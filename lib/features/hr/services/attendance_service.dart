import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import 'package:intl/intl.dart';
import 'dart:developer';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'attendance_logs';

  // --- Store Config Cache ---
  // ดึงพิกัดร้านจาก Firestore config/mobile_app แทน hardcode
  // POS Desktop จะ sync ค่านี้ทุกครั้งที่บันทึก Settings
  double? _cachedStoreLat;
  double? _cachedStoreLng;
  double? _cachedMaxDistance;
  DateTime? _configLoadedAt;

  // Fallback พิกัดร้าน (ใช้เฉพาะกรณี offline / config ยังไม่ sync)
  static const double _defaultStoreLat = 16.160189;
  static const double _defaultStoreLng = 100.802307;
  static const double _defaultMaxDistance = 100.0; // เมตร

  /// ดึงพิกัดร้านจาก Firestore config/mobile_app
  /// cache ไว้ 30 นาที ป้องกัน read ซ้ำ
  Future<Map<String, double>> getStoreConfig() async {
    // ยังอยู่ใน cache window → ใช้ค่าเดิม
    if (_cachedStoreLat != null &&
        _configLoadedAt != null &&
        DateTime.now().difference(_configLoadedAt!).inMinutes < 30) {
      return {
        'lat': _cachedStoreLat!,
        'lng': _cachedStoreLng!,
        'maxDistance': _cachedMaxDistance!,
      };
    }

    try {
      final doc = await _firestore
          .collection('config')
          .doc('mobile_app')
          .get()
          .timeout(const Duration(seconds: 10));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final lat = (data['store_lat'] as num?)?.toDouble();
        final lng = (data['store_lng'] as num?)?.toDouble();
        final maxDist = (data['max_checkin_distance'] as num?)?.toDouble();

        if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
          _cachedStoreLat = lat;
          _cachedStoreLng = lng;
          _cachedMaxDistance = maxDist ?? _defaultMaxDistance;
          _configLoadedAt = DateTime.now();
          log('AttendanceService: Store config loaded — lat=$lat, lng=$lng, maxDist=${_cachedMaxDistance}m');
        } else {
          log('AttendanceService: store_lat/store_lng ยังไม่ได้ตั้งค่าใน Firestore → ใช้ fallback default');
          _setDefaultConfig();
        }
      } else {
        log('AttendanceService: ไม่พบ config/mobile_app → ใช้ fallback default');
        _setDefaultConfig();
      }
    } catch (e) {
      log('AttendanceService: โหลด store config ล้มเหลว: $e → ใช้ fallback default');
      _setDefaultConfig();
    }

    return {
      'lat': _cachedStoreLat ?? _defaultStoreLat,
      'lng': _cachedStoreLng ?? _defaultStoreLng,
      'maxDistance': _cachedMaxDistance ?? _defaultMaxDistance,
    };
  }

  void _setDefaultConfig() {
    _cachedStoreLat ??= _defaultStoreLat;
    _cachedStoreLng ??= _defaultStoreLng;
    _cachedMaxDistance ??= _defaultMaxDistance;
    _configLoadedAt = DateTime.now();
  }

  /// ล้าง cache บังคับโหลดใหม่รอบถัดไป
  void clearConfigCache() {
    _cachedStoreLat = null;
    _cachedStoreLng = null;
    _cachedMaxDistance = null;
    _configLoadedAt = null;
  }

  // --- Attendance CRUD ---

  Future<AttendanceLog?> getTodayLog(String userId) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docId = '${userId}_$today';

    final doc = await _firestore.collection(_collection).doc(docId).get();
    if (doc.exists && doc.data() != null) {
      return AttendanceLog.fromJson(doc.data()!, doc.id);
    }
    return null;
  }

  Stream<AttendanceLog?> todayLogStream(String userId) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docId = '${userId}_$today';

    return _firestore.collection(_collection).doc(docId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return AttendanceLog.fromJson(doc.data()!, doc.id);
      }
      return null;
    });
  }

  Future<void> checkIn(AttendanceLog logEntry) async {
    final docId = '${logEntry.userId}_${logEntry.date}';
    await _firestore.collection(_collection).doc(docId).set(logEntry.toJson());
  }

  Future<void> checkOut(String userId, double lat, double lng, {DateTime? outTime}) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docId = '${userId}_$today';
    final actualOut = outTime ?? DateTime.now();

    await _firestore.collection(_collection).doc(docId).update({
      'check_out_time': actualOut.toIso8601String(),
      'check_out_lat': lat,
      'check_out_lng': lng,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> tempOut(String userId, double lat, double lng) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docId = '${userId}_$today';

    await _firestore.collection(_collection).doc(docId).update({
      'temp_out_time': DateTime.now().toIso8601String(),
      'temp_out_lat': lat,
      'temp_out_lng': lng,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> backToWork(String userId, double lat, double lng) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docId = '${userId}_$today';

    await _firestore.collection(_collection).doc(docId).update({
      'back_to_work_time': DateTime.now().toIso8601String(),
      'back_to_work_lat': lat,
      'back_to_work_lng': lng,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
