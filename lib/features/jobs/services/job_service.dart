// ไฟล์: lib/services/job_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer';
import 'package:s_link/features/jobs/models/job.dart';
import 'package:s_link/features/pos/services/pos_api_service.dart';

class JobService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final String _jobCollection = 'jobs';

  Stream<List<Job>> getJobsByStatus(String status) {
    var query = _firestore
        .collection(_jobCollection)
        .where('status', isEqualTo: status);

    // ✅ ลด Limit เพื่อประหยัด Reads สำหรับงานที่เสร็จแล้ว
    if (status == 'completed') {
      query = query.limit(30); 
    } else if (status == 'requested') {
      query = query.limit(20);
    }

    return query
        .snapshots()
        .map((snapshot) {
          final jobs = snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();
          // ✅ เรียงลำดับในเครื่องแทน เพื่อไม่ต้องใช้ Composite Index บน Firestore
          jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return jobs;
        });
  }

  Stream<List<Job>> getDriverAssignedJobs(List<String> driverIds) {
    final ids = driverIds.where((id) => id.isNotEmpty).toSet().toList();
    final Query<Map<String, dynamic>> query = ids.length == 1
        ? _firestore
            .collection(_jobCollection)
            .where('driver_ids', arrayContains: ids.first)
        : _firestore
            .collection(_jobCollection)
            .where('driver_ids', arrayContainsAny: ids);
    return query
        .snapshots()
        .map((snapshot) {
          final jobs = snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();
          jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return jobs;
        });
  }

  // ✅ Legacy Stream: For old jobs that only have 'driver_id' (string) not array
  Stream<List<Job>> getLegacyDriverAssignedJobs(List<String> driverIds) {
    final ids = driverIds.where((id) => id.isNotEmpty).toSet().toList();
    final Query<Map<String, dynamic>> query = ids.length == 1
        ? _firestore
            .collection(_jobCollection)
            .where('driver_id', isEqualTo: ids.first)
        : _firestore.collection(_jobCollection).where('driver_id', whereIn: ids);
    return query
        .snapshots(includeMetadataChanges: false)
        .map((snapshot) =>
            snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList());
  }

  // ✅ Stream for Pickup Jobs (Pending & Type = pickup or customer_pickup)
  Stream<List<Job>> getPickupJobs() {
    return _firestore
        .collection(_jobCollection)
        .where('status', isEqualTo: 'pending')
        .where('job_type', whereIn: ['pickup', 'customer_pickup'])
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList());
  }

  // ✅ ดึงงานเสร็จแล้วจาก POS Backend API (MySQL) — ไม่ใช้ Firebase เพราะงานเสร็จแล้วถูกลบไปจาก Firebase
  Future<List<Job>> getCompletedJobsByDateRange(
      DateTime startDate, DateTime endDate) async {
    try {
      final rows = await PosApiService().getDeliveryHistory(
        startDate: startDate,
        endDate: endDate,
      );
      final jobs = rows.map((row) => Job.fromHistory(row)).toList();
      log('JobService: Fetched ${jobs.length} history jobs from API for $startDate - $endDate');
      return jobs;
    } catch (e) {
      log('JobService: getCompletedJobsByDateRange API error: $e');
      return [];
    }
  }

  // ดึงงานเสร็จแล้วทั้งหมดสำหรับ Report
  Future<List<Job>> getAllCompletedJobsForReport() async {
    final snapshot = await _firestore
        .collection(_jobCollection)
        .where('status', isEqualTo: 'completed')
        .orderBy('completed_at', descending: true)
        .get();
    return snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();
  }

  // ✅ [Cost Optimization] ฟังเฉพาะงานที่ตัวเองสร้าง (สำหรับ Requester)
  Stream<List<Job>> getJobsByStatusAndCreator(String status, String creatorId) {
    return _firestore
        .collection(_jobCollection)
        .where('status', isEqualTo: status)
        .where('created_by', isEqualTo: creatorId) // กรองเฉพาะของตัวเอง
        .orderBy('created_at', descending: true)
        .limit(50) // Limit ไว้ด้วย
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList());
  }

  // --- Actions ---

  Future<void> createJob(Job newJob) async {
    final jobData = newJob.toFirestore();
    jobData['created_at'] = FieldValue.serverTimestamp();
    jobData['status'] = 'pending';
    // Ensure Defaults
    jobData['driver_id'] = '';
    jobData['proof_image'] = null;

    await _firestore.collection(_jobCollection).add(jobData);
  }

  Future<void> claimJob(String jobId, String driverUid) async {
    await _firestore.collection(_jobCollection).doc(jobId).update({
      'driver_id': driverUid,
    });
  }

  Future<void> completeJob(
    String jobId, {
    required String driverUid,
    required String proofImage,
    required GeoPoint proofLocation,
    required List<Map<String, dynamic>> deliveryTeamData,
    double? collectedCod,
  }) async {
    final Map<String, dynamic> updates = {
      'status': 'completed',
      'completed_at': FieldValue.serverTimestamp(),
      'driver_id': driverUid,
    };

    if (proofImage.isNotEmpty) {
      updates['proof_image'] = proofImage;
    }

    if (collectedCod != null) {
      updates['collected_cod'] = collectedCod;
    }

    await _firestore.collection(_jobCollection).doc(jobId).update(updates);
  }

  // ✅ Complete Pickup Job (Simplified flow)
  Future<void> completePickupJob(String jobId, String staffUid) async {
    await _firestore.collection(_jobCollection).doc(jobId).update({
      'status': 'completed',
      'completed_at': FieldValue.serverTimestamp(),
      'driver_id': staffUid, // Record who processed it
      'proof_image': '', // Optional/Empty for pickup
      'is_departure_approved': true, // Auto decide
    });
  }

  Future<void> deleteJob(String jobId) async {
    await _firestore.collection(_jobCollection).doc(jobId).delete();
  }

  // ✅ Generic Update Status
  Future<void> updateJobStatus(String jobId, String status) async {
    await _firestore
        .collection(_jobCollection)
        .doc(jobId)
        .update({'status': status});
  }

  // Recursive Batch Delete (ลบงานที่เสร็จแล้วทั้งหมด)
  Future<int> deleteAllCompletedJobs() async {
    const batchSize = 500;

    final querySnapshot = await _firestore
        .collection(_jobCollection)
        .where('status', isEqualTo: 'completed')
        .limit(batchSize)
        .get();

    final docsToDelete = querySnapshot.docs;
    final totalInBatch = docsToDelete.length;

    if (totalInBatch == 0) return 0;

    final batch = _firestore.batch();
    for (var doc in docsToDelete) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    log('Deleted $totalInBatch jobs.');

    if (totalInBatch == batchSize) {
      // เรียกตัวเองซ้ำถ้ายังมีเหลือ
      return totalInBatch + await deleteAllCompletedJobs();
    }

    return totalInBatch;
  }
}
