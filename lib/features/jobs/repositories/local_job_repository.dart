// ไฟล์: lib/features/jobs/repositories/local_job_repository.dart
// [Milestone 2] Repository สำหรับแปลงข้อมูลจาก SQLite Row กลับเป็น Job Model

import 'dart:convert';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:s_link/core/database/local_db_service.dart';
import 'package:s_link/features/jobs/models/job.dart';
import 'package:s_link/features/jobs/models/job_item.dart';

class LocalJobRepository {
  final LocalDbService _db = LocalDbService();
  static const String _tag = '[LocalJobRepo]';

  // ═══════════════════════════════════════════════════
  // READ
  // ═══════════════════════════════════════════════════

  /// โหลดงานที่ยัง active ทั้งหมดจาก Local DB แปลงเป็น Job Model
  Future<List<Job>> getActiveJobs() async {
    log('$_tag Fetching active jobs from SQLite...');
    final rows = await _db.getActiveJobs();
    final jobs = rows.map(_rowToJob).toList();
    log('$_tag Loaded ${jobs.length} active jobs');
    return jobs;
  }

  /// โหลดทุกงาน (รวมที่ปิดแล้ว)
  Future<List<Job>> getAllJobs() async {
    final rows = await _db.getAllJobs();
    return rows.map(_rowToJob).toList();
  }

  Future<Job?> getJobByOrderId(int orderId) async {
    final row = await _db.getJobByOrderId(orderId);
    if (row == null) return null;
    return _rowToJob(row);
  }

  // ═══════════════════════════════════════════════════
  // WRITE
  // ═══════════════════════════════════════════════════

  /// บันทึกหรืออัปเดตงานจาก API Response (List)
  Future<void> syncFromApi(List<Map<String, dynamic>> apiJobs) async {
    log('$_tag Syncing ${apiJobs.length} jobs from API into local DB...');
    for (final job in apiJobs) {
      await _db.upsertJob(job);
    }
    log('$_tag Sync complete: ${apiJobs.length} jobs saved');
  }

  /// บันทึกผลการปิดงานลงเครื่องก่อน (Local-first)
  Future<void> markCompleted({
    required int orderId,
    required String proofImagePath,
    required double proofLat,
    required double proofLng,
  }) async {
    log('$_tag Marking orderId=$orderId as completed (local-first)');
    await _db.markJobCompleted(
      orderId: orderId,
      proofImagePath: proofImagePath,
      proofLat: proofLat,
      proofLng: proofLng,
    );
  }

  /// ลบงานออกจากเครื่องเมื่อ sync กับ server สำเร็จแล้ว
  Future<void> deleteJob(int orderId) async {
    log('$_tag Deleting job orderId=$orderId from local DB after sync');
    await _db.deleteJob(orderId);
  }

  /// ล้างแคชเก่า (เรียกตอนเปิดแอป)
  Future<int> cleanupOldJobs() async {
    return await _db.cleanupOldCompletedJobs();
  }

  // ═══════════════════════════════════════════════════
  // SYNC QUEUE
  // ═══════════════════════════════════════════════════

  Future<int> enqueueOfflineJob(Map<String, dynamic> data) async {
    log('$_tag Enqueueing offline job for later sync (jobId=${data['jobId']})');
    return await _db.enqueueSync(data);
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    return await _db.getPendingSyncItems();
  }

  Future<void> markSyncItemStatus(int id, String status) async {
    await _db.updateSyncStatus(id, status);
  }

  Future<void> removeSyncItem(int id) async {
    await _db.removeSyncItem(id);
  }

  // ═══════════════════════════════════════════════════
  // DIAGNOSTICS
  // ═══════════════════════════════════════════════════

  Future<Map<String, int>> getDiagnostics() async {
    return await _db.getDiagnostics();
  }

  Future<void> clearAll() async {
    log('$_tag WARNING: Clearing all local data (user-initiated reset)');
    await _db.clearAll();
  }

  // ═══════════════════════════════════════════════════
  // MAPPER: SQLite Row → Job Model
  // ═══════════════════════════════════════════════════

  Job _rowToJob(Map<String, dynamic> row) {
    final orderId = int.tryParse(row['orderId']?.toString() ?? '0') ?? 0;

    // แปลง itemsJson กลับเป็น List<JobItem> โดยใช้ JobItem.fromJson
    List<JobItem> items = [];
    try {
      final decoded = jsonDecode(row['itemsJson']?.toString() ?? '[]');
      if (decoded is List) {
        items = decoded.map<JobItem>((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return JobItem.fromJson(m);
        }).toList();
      }
    } catch (e) {
      log('$_tag Warning: Could not parse itemsJson for orderId=$orderId: $e');
    }

    // แปลง GeoPoint สำหรับพิกัดลูกค้า
    GeoPoint? destLocation;
    final lat = double.tryParse(row['customerLat']?.toString() ?? '');
    final lng = double.tryParse(row['customerLng']?.toString() ?? '');
    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      destLocation = GeoPoint(lat, lng);
    }

    // แปลง GeoPoint สำหรับพิกัดหลักฐาน (ถ้ามี - งานปิดแล้วรอ sync)
    GeoPoint? proofLocation;
    final pLat = double.tryParse(row['proofLat']?.toString() ?? '');
    final pLng = double.tryParse(row['proofLng']?.toString() ?? '');
    if (pLat != null && pLng != null && pLat != 0.0) {
      proofLocation = GeoPoint(pLat, pLng);
    }

    return Job(
      id:             'local_$orderId',
      localOrderId:   orderId,
      status:         row['status']?.toString() ?? 'pending',
      jobType:        row['jobType']?.toString() ?? 'delivery',
      paymentMethod:  row['paymentMethod']?.toString() ?? 'cash',
      price:          double.tryParse(row['totalAmount']?.toString() ?? '0') ?? 0.0,
      details:        row['note']?.toString(),
      proofImage:     row['proofImagePath']?.toString(),
      proofLocation:  proofLocation,
      destinationLocation: destLocation,
      isDepartureApproved: true,
      createdAt:      _parseDate(row['createdAt']) ?? DateTime.now(),
      completedAt:    _parseDate(row['completedAt']),
      customer: Customer(
        name:        row['customerName']?.toString() ?? '',
        phoneNumber: row['customerPhone']?.toString() ?? '',
        address:     row['customerAddress']?.toString() ?? '',
      ),
      items: items,
      deliveryTeam: [],
      driverIds: [],
      vehicleIds: [],
      billImageUrls: [],
      createdBy: '',
    );
  }

  DateTime? _parseDate(dynamic val) {
    if (val == null || val.toString().isEmpty) return null;
    try { return DateTime.parse(val.toString()); } catch (_) { return null; }
  }
}
