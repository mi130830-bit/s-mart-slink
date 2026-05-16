// ไฟล์: lib/services/alert_log_service.dart
// Stock Alert Management ถูกย้ายไปใช้ API ผ่าน ShortageRepository แล้ว
// เหลือเฉพาะ Shop Work Log Management ที่ยังใช้ Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';
import 'package:s_link/features/jobs/models/shop_work_log.dart';

class AlertLogService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // ----------------------------------------------------
  // SHOP WORK LOG MANAGEMENT
  // ----------------------------------------------------

  final String _logCollection = 'shop_work_logs';

  Future<void> createWorkLog(String delivererId, List<WorkItem> items) async {
    try {
      final newLog = ShopWorkLogModel(
        id: '',
        delivererId: delivererId,
        items: items,
        loggedAt: DateTime.now(),
      );

      final logData = newLog.toFirestore();
      logData['logged_at'] = FieldValue.serverTimestamp();

      await _firestore.collection(_logCollection).add(logData);
      log('Shop work log created by $delivererId with ${items.length} items.');
    } catch (e) {
      log('Error creating work log: $e');
      throw Exception('Failed to create shop work log');
    }
  }

  // ✅ [แก้ไข] จำกัดการดึงข้อมูล Log ล่าสุดแค่ 50 รายการ
  Stream<List<ShopWorkLogModel>> getAllWorkLogs() {
    return _firestore
        .collection(_logCollection)
        .orderBy('logged_at', descending: true)
        .limit(10) // Limit เพื่อประหยัดค่า Read
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ShopWorkLogModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<ShopWorkLogModel>> getWorkLogsByDeliverer(String delivererId) {
    return _firestore
        .collection(_logCollection)
        .where('deliverer_id', isEqualTo: delivererId)
        .orderBy('logged_at', descending: true)
        .limit(20) // Limit ของส่วนบุคคล
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ShopWorkLogModel.fromFirestore(doc))
            .toList());
  }

  Future<void> deleteWorkLog(String logId) async {
    try {
      await _firestore.collection(_logCollection).doc(logId).delete();
      log('Work log deleted: $logId');
    } catch (e) {
      log('Error deleting work log: $e');
      throw Exception('Failed to delete work log');
    }
  }

  Future<List<ShopWorkLogModel>> getWorkLogsByDateRange(
      DateTime start, DateTime end) async {
    try {
      final snapshot = await _firestore
          .collection(_logCollection)
          .where('logged_at', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('logged_at', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      return snapshot.docs
          .map((doc) => ShopWorkLogModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      log('Error getting work logs by date range: $e');
      return [];
    }
  }
}
