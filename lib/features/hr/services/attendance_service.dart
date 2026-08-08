import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import '../models/attendance_model.dart';
import '../models/attendance_log_isar.dart';
import '../../../services/isar_service.dart';
import '../../pos/services/pos_api_service.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final IsarService _isarService = IsarService();
  final PosApiService _apiService = PosApiService();

  // --- Store Config Cache (Keep Firestore for config if needed, or change to API) ---
  // If config is still in Firestore, keep this as is.
  double? _cachedStoreLat;
  double? _cachedStoreLng;
  double? _cachedMaxDistance;
  DateTime? _configLoadedAt;

  static const double _defaultStoreLat = 16.160189;
  static const double _defaultStoreLng = 100.802307;
  static const double _defaultMaxDistance = 100.0;

  Future<Map<String, double>> getStoreConfig() async {
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
        _cachedStoreLat = (data['store_lat'] as num?)?.toDouble();
        _cachedStoreLng = (data['store_lng'] as num?)?.toDouble();
        _cachedMaxDistance =
            (data['max_checkin_distance'] as num?)?.toDouble() ??
                _defaultMaxDistance;
        _configLoadedAt = DateTime.now();
      } else {
        _setDefaultConfig();
      }
    } catch (e) {
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

  void clearConfigCache() {
    _cachedStoreLat = null;
    _cachedStoreLng = null;
    _cachedMaxDistance = null;
    _configLoadedAt = null;
  }

  // --- Attendance CRUD with Isar & API ---

  String _getSyncId(String userId, String dateStr) {
    return '${userId}_$dateStr';
  }

  Future<AttendanceLog?> getTodayLog(String userId) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final syncId = _getSyncId(userId, today);

    final isar = await _isarService.db;
    final isarLog = await isar.attendanceLogIsars
        .filter()
        .syncIdEqualTo(syncId)
        .findFirst();

    if (isarLog != null) {
      return _mapIsarToModel(isarLog);
    }
    return null;
  }

  Stream<AttendanceLog?> todayLogStream(String userId) async* {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final syncId = _getSyncId(userId, today);

    final isar = await _isarService.db;

    // First emit current state
    final current = await isar.attendanceLogIsars
        .filter()
        .syncIdEqualTo(syncId)
        .findFirst();
    yield current != null ? _mapIsarToModel(current) : null;

    // Then listen to changes
    yield* isar.attendanceLogIsars
        .filter()
        .syncIdEqualTo(syncId)
        .watch(fireImmediately: false)
        .map((results) {
      if (results.isNotEmpty) {
        return _mapIsarToModel(results.first);
      }
      return null;
    });
  }

  Future<void> fetchTodayLogFromServer(String userId) async {
    try {
      await syncUnsyncedLogs();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await _apiService
          .getRaw('/hr/attendance/today?user_id=$userId&date=$today');

      if (response != null &&
          response is Map<String, dynamic> &&
          response['id'] != null) {
        // We got data from server, let's update local Isar
        final syncId = _getSyncId(userId, today);
        final isar = await _isarService.db;

        await isar.writeTxn(() async {
          final isarLog = await isar.attendanceLogIsars
                  .filter()
                  .syncIdEqualTo(syncId)
                  .findFirst() ??
              (AttendanceLogIsar()
                ..syncId = syncId
                ..userId = userId
                ..date = today);

          // Only overwrite local if it's currently synced or we just created it.
          // Or we can just blindly overwrite with server state since server is source of truth for fingerprint.
          DateTime? checkIn = response['check_in_time'] != null
              ? DateTime.parse(response['check_in_time'])
              : null;
          DateTime? checkOut = response['check_out_time'] != null
              ? DateTime.parse(response['check_out_time'])
              : null;

          if (checkIn != null &&
              checkOut != null &&
              checkOut.isBefore(checkIn)) {
            checkOut = null; // Stale check out from prior cycle
          }

          isarLog.checkInTime = checkIn;
          isarLog.checkOutTime = checkOut;
          isarLog.tempOutTime = response['temp_out_time'] != null
              ? DateTime.parse(response['temp_out_time'])
              : null;
          isarLog.backToWorkTime = response['back_to_work_time'] != null
              ? DateTime.parse(response['back_to_work_time'])
              : null;
          double? parseDouble(dynamic value) {
            if (value == null) return null;
            if (value is double) return value;
            if (value is int) return value.toDouble();
            if (value is String) return double.tryParse(value);
            return null;
          }

          isarLog.checkInLat = parseDouble(response['check_in_lat']);
          isarLog.checkInLng = parseDouble(response['check_in_lng']);
          isarLog.status = response['status'];
          isarLog.note = response['note'];

          isarLog.isSynced = true; // Since it came from server
          await isar.attendanceLogIsars.put(isarLog);
        });
      }
    } catch (e) {
      log('AttendanceService: Failed to fetch today log from server: $e');
    }
  }

  Future<void> _saveAndSync(
    String userId,
    Function(AttendanceLogIsar) updateFn, {
    bool requireServer = false,
  }) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final syncId = _getSyncId(userId, today);
    final isar = await _isarService.db;

    await isar.writeTxn(() async {
      final isarLog = await isar.attendanceLogIsars
              .filter()
              .syncIdEqualTo(syncId)
              .findFirst() ??
          (AttendanceLogIsar()
            ..syncId = syncId
            ..userId = userId
            ..date = today
            ..status = 'PRESENT');

      updateFn(isarLog);

      isarLog.lastModified = DateTime.now();
      isarLog.isSynced = false;
      await isar.attendanceLogIsars.put(isarLog);
    });

    // Try to sync immediately
    await syncUnsyncedLogs(throwOnFailure: requireServer);
  }

  Future<void> checkIn(
    AttendanceLog logEntry, {
    bool requireServer = false,
  }) async {
    await _saveAndSync(logEntry.userId, (isarLog) {
      isarLog.checkInTime = logEntry.checkInTime;
      isarLog.checkInLat = logEntry.checkInLat;
      isarLog.checkInLng = logEntry.checkInLng;
      isarLog.userName = logEntry.userName;
      isarLog.note = logEntry.note;
      isarLog.status = logEntry.status;
    }, requireServer: requireServer);
  }

  Future<void> checkOut(
    String userId,
    double lat,
    double lng, {
    DateTime? outTime,
    bool requireServer = false,
  }) async {
    await _saveAndSync(userId, (isarLog) {
      isarLog.checkOutTime = outTime ?? DateTime.now();
      isarLog.checkOutLat = lat;
      isarLog.checkOutLng = lng;
    }, requireServer: requireServer);
  }

  Future<void> tempOut(String userId, double lat, double lng) async {
    await _saveAndSync(userId, (isarLog) {
      isarLog.tempOutTime = DateTime.now();
      isarLog.tempOutLat = lat;
      isarLog.tempOutLng = lng;
      isarLog.backToWorkTime = null; // Reset back to work if taking a new break
    });
  }

  Future<void> backToWork(String userId, double lat, double lng) async {
    await _saveAndSync(userId, (isarLog) {
      isarLog.backToWorkTime = DateTime.now();
      isarLog.backToWorkLat = lat;
      isarLog.backToWorkLng = lng;
    });
  }

  Future<void> saveNote(String userId, String note) async {
    await _saveAndSync(userId, (isarLog) {
      isarLog.note = note;
    });
  }

  // --- Mapping ---
  AttendanceLog _mapIsarToModel(AttendanceLogIsar isarLog) {
    return AttendanceLog(
      id: isarLog.syncId ?? '',
      userId: isarLog.userId ?? '',
      userName: isarLog.userName ?? '',
      date: isarLog.date ?? '',
      checkInTime: isarLog.checkInTime,
      checkOutTime: isarLog.checkOutTime,
      tempOutTime: isarLog.tempOutTime,
      backToWorkTime: isarLog.backToWorkTime,
      checkInLat: isarLog.checkInLat,
      checkInLng: isarLog.checkInLng,
      checkOutLat: isarLog.checkOutLat,
      checkOutLng: isarLog.checkOutLng,
      tempOutLat: isarLog.tempOutLat,
      tempOutLng: isarLog.tempOutLng,
      backToWorkLat: isarLog.backToWorkLat,
      backToWorkLng: isarLog.backToWorkLng,
      status: isarLog.status ?? 'PRESENT',
      note: isarLog.note,
      isSynced: isarLog.isSynced,
    );
  }

  // --- API Sync Logic ---
  Future<void> syncUnsyncedLogs({bool throwOnFailure = false}) async {
    final isar = await _isarService.db;
    final unsyncedLogs =
        await isar.attendanceLogIsars.filter().isSyncedEqualTo(false).findAll();

    if (unsyncedLogs.isEmpty) return;

    try {
      List<Map<String, dynamic>> payload = unsyncedLogs
          .map((log) => {
                'sync_id': log.syncId,
                'user_id': log.userId,
                'date': log.date,
                'check_in_time': log.checkInTime?.toIso8601String(),
                'check_out_time': log.checkOutTime?.toIso8601String(),
                'temp_out_time': log.tempOutTime?.toIso8601String(),
                'back_to_work_time': log.backToWorkTime?.toIso8601String(),
                'check_in_lat': log.checkInLat,
                'check_in_lng': log.checkInLng,
                'check_out_lat': log.checkOutLat,
                'check_out_lng': log.checkOutLng,
                'temp_out_lat': log.tempOutLat,
                'temp_out_lng': log.tempOutLng,
                'back_to_work_lat': log.backToWorkLat,
                'back_to_work_lng': log.backToWorkLng,
                'status': log.status,
                'note': log.note,
              })
          .toList();

      // We use the new POS API route
      final response =
          await _apiService.postRaw('/hr/attendance/sync', {'logs': payload});

      if (response['status'] == 'success') {
        // Mark as synced
        await isar.writeTxn(() async {
          for (var log in unsyncedLogs) {
            log.isSynced = true;
            await isar.attendanceLogIsars.put(log);
          }
        });
        log('AttendanceService: Synced ${unsyncedLogs.length} logs to MySQL.');
      } else if (throwOnFailure) {
        throw StateError('POS did not confirm attendance sync');
      }
    } catch (e) {
      log('AttendanceService: Failed to sync to MySQL: $e');
      if (throwOnFailure) throw AttendanceSyncException(e);
    }
  }

  // To be called by a background task periodically (every hour)
  Future<void> backgroundCleanupAndSync() async {
    await syncUnsyncedLogs();

    // Optional: cleanup old logs from Isar (e.g. older than 30 days) to save space
    final isar = await _isarService.db;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final oldDateStr = DateFormat('yyyy-MM-dd').format(thirtyDaysAgo);

    await isar.writeTxn(() async {
      await isar.attendanceLogIsars
          .filter()
          .dateLessThan(oldDateStr)
          .deleteAll();
    });
  }
}

class AttendanceSyncException implements Exception {
  final Object cause;
  const AttendanceSyncException(this.cause);

  @override
  String toString() => 'Attendance sync failed: $cause';
}
