// ไฟล์: lib/providers/alert_log_provider.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer';

import 'package:s_link/features/alerts/services/alert_log_service.dart';
import 'package:s_link/features/alerts/services/shortage_repository.dart';
import 'package:s_link/features/alerts/models/shortage_log_model.dart';
import 'package:s_link/features/jobs/models/shop_work_log.dart';
import 'package:s_link/features/hr/services/work_log_sync_service.dart';
import 'package:s_link/features/hr/models/shop_work_log_isar.dart';
import 'package:s_link/services/isar_service.dart';

class AlertLogProvider with ChangeNotifier {
  final ShortageRepository _shortageRepository = ShortageRepository();

  StreamSubscription? _allWorkLogsSubscription;

  // Changed from StockAlertModel (Firestore) to ShortageLogModel (MySQL)
  List<ShortageLogModel> _openAlerts = [];
  List<ShopWorkLogModel> _allWorkLogs = [];
  final Map<String, String> _workLogDelivererNames = {};
  bool _isLoading = false;

  List<ShortageLogModel> get openAlerts => _openAlerts;
  List<ShopWorkLogModel> get allWorkLogs => _allWorkLogs;
  bool get isLoading => _isLoading;

  // Timer for polling MySQL (Optional, to mimic Firestore Stream)
  Timer? _pollingTimer;

  AlertLogProvider(AlertLogService _);

  void startListeningToAlertsAndLogs(String? role) {
    // ปิดของเก่าก่อนเสมอ เพื่อป้องกัน Memory Leak หรือ Listener ซ้อนทับ
    stopListening();

    log('AlertLogProvider: Starting listeners for role: $role');
    _isLoading = true;
    notifyListeners();

    // 1. Fetch Open Alerts from MySQL
    // Since MySQL doesn't support streams natively like Firestore, we fetch initially
    // and can set up a polling timer if real-time updates are crucial.
    _fetchOpenShortages();

    // Setup Polling every 60 seconds (Reduced from 15s to save battery/logs)
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 300), (_) {
      _fetchOpenShortages(silent: true);
    });

    // 2. ฟัง Work Logs (ประวัติงานหลังบ้าน) - เฉพาะ Admin เท่านั้นที่เห็นทั้งหมด
    if (role?.toLowerCase() == 'admin') {
      final syncService = WorkLogSyncService(IsarService());
      
      // ดึงข้อมูลล่าสุดจาก API ลง Local โดยไม่รอทับคิวงานออฟไลน์
      unawaited(refreshWorkLogs());
      
      _allWorkLogsSubscription =
          syncService.watchWorkLogs().listen((isarData) {
        _allWorkLogs = isarData.map((isarLog) {
          return ShopWorkLogModel(
            id: isarLog.syncId ?? isarLog.id.toString(),
            delivererId: isarLog.delivererId ?? '',
            delivererName: _workLogDelivererNames[
                isarLog.syncId ?? isarLog.id.toString()],
            loggedAt: isarLog.loggedAt ?? DateTime.now(),
            items: isarLog.items?.map((item) => WorkItem(
              description: item.description ?? '',
              quantity: item.quantity ?? 1.0,
              unit: item.unit ?? 'ครั้ง',
            )).toList() ?? [],
          );
        }).toList();
        log('AlertLogProvider: Updated ${_allWorkLogs.length} work logs from Isar.');
        notifyListeners();
      }, onError: (e) {
        log('AlertLogProvider Error (Logs): $e');
      });
    } else {
      // ถ้าไม่ใช่ Admin ให้หยุดโหลดในส่วนนี้ (แต่ Alerts ยังทำงานต่อ)
      _isLoading = false;
      notifyListeners();
    }
  }

  // ยกเลิก Stream ทั้งหมด
  void stopListening() {
    log('AlertLogProvider: Stopping all listeners...');
    _pollingTimer?.cancel();
    _allWorkLogsSubscription?.cancel();

    _pollingTimer = null;
    _allWorkLogsSubscription = null;

    _openAlerts = [];
    _allWorkLogs = [];
    _isLoading = false;

    notifyListeners();
  }

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> _fetchOpenShortages({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null; // Clear error
      notifyListeners();
    }

    try {
      final data = await _shortageRepository.getOpenShortages();
      _openAlerts = data;
      _errorMessage = null;
      if (!silent) {
        log('✅ AlertLogProvider: Fetched ${_openAlerts.length} items from API');
      }
    } catch (e) {
      _errorMessage = 'Load Error: $e';
      log('❌ AlertLogProvider Error: $e');
      _openAlerts = []; // Clear list on error
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    }
  }

  // ---------------------------------------------------------
  // ACTIONS (การกระทำต่างๆ)
  // ---------------------------------------------------------

  // 1. สร้างแจ้งเตือนของหมด (MySQL + Firestore Trigger)
  Future<void> createAlert(String name, String uid) async {
    await _shortageRepository.createShortage(name, uid);
    // Refresh list immediately
    await _fetchOpenShortages(silent: true);
  }

  // 2. ลบแจ้งเตือน (MySQL Delete)
  Future<void> markAsDone(dynamic alertId) async {
    // alertId might be int now
    final id = int.tryParse(alertId.toString());
    if (id != null) {
      await _shortageRepository.markAsDone(id);
      await _fetchOpenShortages(silent: true);
    }
  }

  // 2.1 Mark as Ordered (MySQL Update)
  Future<void> markAsOrdered(dynamic alertId) async {
    final id = int.tryParse(alertId.toString());
    if (id != null) {
      await _shortageRepository.markAsOrdered(id);
      await _fetchOpenShortages(silent: true);
    }
  }

  // 3. สร้างบันทึกงานหลังบ้าน (Offline-First)
  Future<void> createWorkLog(String delivererId, List<WorkItem> items) async {
    final syncService = WorkLogSyncService(IsarService());
    // Convert WorkItem to WorkItemIsar
    final isarItems = items.map((e) => WorkItemIsar()
      ..description = e.description
      ..quantity = e.quantity
      ..unit = e.unit).toList();
      
    await syncService.addWorkLog(delivererId, isarItems);
  }

  // ✅ 4. [เพิ่มใหม่] ลบบันทึกงานหลังบ้าน (Offline-First)
  Future<void> deleteWorkLog(String logId) async {
    final syncService = WorkLogSyncService(IsarService());
    await syncService.deleteWorkLog(logId);
  }

  /// Refreshes only shop-work history. This must not restart the shortage
  /// listener used by other screens.
  Future<void> refreshWorkLogs() async {
    final syncService = WorkLogSyncService(IsarService());
    final names = await syncService.syncDownWorkLogs();
    if (names.isNotEmpty) {
      _workLogDelivererNames.addAll(names);
      notifyListeners();
    }
  }

  // ✅ 5. ค้นหาสินค้า (Autocomplete)
  Future<List<ProductSearchResult>> searchProducts(String query) async {
    return await _shortageRepository.searchProducts(query);
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
