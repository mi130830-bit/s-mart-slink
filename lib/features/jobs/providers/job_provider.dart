// ไฟล์: lib/providers/job_provider.dart (ฉบับแก้ไขและสมบูรณ์)

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

import 'package:s_link/core/services/sync_service.dart';

import 'package:s_link/features/jobs/services/job_service.dart';
import 'package:s_link/features/pos/services/pos_api_service.dart';

import 'package:s_link/core/services/notification_service.dart';
import 'package:s_link/features/jobs/models/job.dart';
import 'package:s_link/features/auth/models/user.dart'; // User moved to Auth
// import 'package:s_link/features/jobs/models/job_status.dart'; // No longer used in filters

class JobProvider with ChangeNotifier {
  final JobService _jobService;


  StreamSubscription? _pendingJobsSubscription;
  StreamSubscription? _driverAssignedJobsSubscription;
  StreamSubscription? _legacyJobsSubscription; // ✅ Legacy Stream

  List<Job> _pendingJobs = [];
  List<Job> _completedJobs = [];
  List<Job> _statsJobs = []; // ✅ เพิ่มตัวแปรสำหรับเก็บข้อมูลสถิติ
  List<Job> _driverAssignedJobs = [];
  List<Job> _legacyAssignedJobs = [];
  List<Job> _localAssignedJobs = []; // ✅ Buffer for optimistic updates
  Map<String, dynamic> _summaryStats = {}; // ✅ เก็บสถิติรายคน/รายรถจาก Backend
  bool _isLoading = false;
  String? _pendingJobsError; // ✅ Track Firestore query errors
  UserModel? _currentUser;

  List<Job> get pendingJobs => _pendingJobs;
  List<Job> get completedJobs => _completedJobs;
  List<Job> get statsJobs => _statsJobs;
  String? get pendingJobsError => _pendingJobsError; // ✅ Expose error to UI
  Map<String, dynamic> get summaryStats => _summaryStats;
  List<Job> get driverAssignedJobs {
    final Map<String, Job> jobMap = {};

    // 1. Legacy
    for (var job in _legacyAssignedJobs) {
      jobMap[job.id] = job;
    }
    // 2. Stream (Driver Assigned)
    for (var job in _driverAssignedJobs) {
      jobMap[job.id] = job;
    }
    // 3. Fallback: Pending jobs assigned to me
    if (_currentUser != null) {
      for (var job in _pendingJobs) {
        final isAssigned = job.driverIds.contains(_currentUser!.uid) ||
            job.driverId == _currentUser!.uid;
        if (isAssigned) {
          jobMap[job.id] = job;
        }
      }
    }
    // 4. ✅ Local Buffer (High priority, prevents flickering)
    for (var job in _localAssignedJobs) {
      jobMap[job.id] = job;
    }

    final merged = jobMap.values.toList();
    final activeJobs =
        merged.where((job) => job.status != 'completed').toList();

    activeJobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return activeJobs;
  }

  bool get isLoading => _isLoading;

  JobProvider(this._jobService);

  void stopListening() {
    log('JobProvider: Stopping all listeners...');
    _pendingJobsSubscription?.cancel();
    _driverAssignedJobsSubscription?.cancel();
    _legacyJobsSubscription?.cancel();

    _pendingJobsSubscription = null;
    _driverAssignedJobsSubscription = null;
    _legacyJobsSubscription = null;

    _pendingJobs = [];
    _completedJobs = [];
    _statsJobs = [];
    _driverAssignedJobs = [];
    _legacyAssignedJobs = [];
    _localAssignedJobs = []; // ✅ Clear local buffer
    _isLoading = false;
    _pendingJobsError = null; // ✅ Clear error

    notifyListeners();
  }

  Future<void> fetchCompletedJobsByRange(
      DateTime startDate, DateTime endDate) async {
    try {
      _isLoading = true;
      notifyListeners();

      final jobs =
          await _jobService.getCompletedJobsByDateRange(startDate, endDate);
      _completedJobs = jobs;
      log('JobProvider: Fetched ${_completedJobs.length} completed jobs for $startDate - $endDate');
    } catch (e) {
      log('JobProvider Error fetching completed jobs: $e');
      _completedJobs = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ ฟังก์ชันดึงสถิติจากการคำนวณของ MySQL Backend (แม่นยำ 100% ตรวจสอบจากประวัติการส่ง)
  Future<void> fetchSummaryStats() async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await PosApiService().getJobSummaryStats();
      if (response != null && response['success'] == true) {
        _summaryStats = response;
        log('✅ [JobProvider] Summary Stats Loaded: ${response['totalJobs']} jobs');
      }
    } catch (e) {
      log('❌ [JobProvider] fetchSummaryStats Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ ฟังก์ชันดึงประวัติงานล่าสุดย้อนหลังจาก MySQL (แทนที่ Firestore)
  Future<void> fetchJobStats({int limit = 100}) async {
    try {
      _isLoading = true;
      notifyListeners();

      // ดึงจาก MySQL แทน Firestore เพราะ Firebase ถูกลบทิ้งหลังจบงาน
      final now = DateTime.now();
      final sixtyDaysAgo = now.subtract(const Duration(days: 60));
      
      final history = await PosApiService().getDeliveryHistory(
        startDate: sixtyDaysAgo,
        endDate: now,
      );

      _statsJobs = history.map((m) => Job.fromHistory(m)).toList();
      log('JobProvider: Fetched ${_statsJobs.length} jobs from MySQL history (Backend).');
    } catch (e) {
      log('JobProvider Error fetching stats from backend: $e');
      _statsJobs = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshStreams() async {
    log('JobProvider: Manual Refresh Requested');
    stopListening();
    if (_currentUser != null) {
      startListeningToJobs(_currentUser);
    }
    notifyListeners();
  }

  void startListeningToJobs(UserModel? currentUser) {
    if (currentUser == null) {
      log('JobProvider: User is null, cannot start listeners.');
      return;
    }
    _currentUser = currentUser;

    SyncService().startMonitoring();

    stopListening();

    _isLoading = true;
    notifyListeners();

    final role = currentUser.role.name.toLowerCase();

    NotificationService.initialize();

    // 1. ฟัง Pending Jobs
    _pendingJobsSubscription =
        _jobService.getJobsByStatus('pending').listen((jobs) {
      // Check for new jobs
      if (_pendingJobs.isNotEmpty && jobs.length > _pendingJobs.length) {
        final newCount = jobs.length - _pendingJobs.length;
        NotificationService.showLocalNotification(
          title: 'มีงานส่งของใหม่!',
          body: 'มีงานใหม่เข้ามา $newCount งาน',
        );
      } else if (_pendingJobs.isEmpty && jobs.isNotEmpty) {
        // First load or from empty
        log('JobProvider: Loaded ${jobs.length} pending jobs (Initial or from empty). No notification triggered.');
      }

      _pendingJobs = jobs;
      _pendingJobsError = null; // ✅ Clear error on success
      _isLoading = false;
      notifyListeners();
    }, onError: (e, stack) {
      log('JobProvider CRITICAL ERROR: $e');
      log('Stacktrace: $stack');
      _pendingJobsError = e.toString(); // ✅ Save error for UI
      _isLoading = false;
      notifyListeners(); // ✅ Notify so UI can show error state
    });

    // 2. Load Completed Jobs (Initial load for Today)
    if (role == 'admin' || role == 'requester') {
      final today = DateTime.now();
      fetchCompletedJobsByRange(today, today);
    }

    // 3. ฟังงาน Driver (Always listen for assigned jobs for ALL roles to prevent missing jobs)
    _driverAssignedJobsSubscription =
        _jobService.getDriverAssignedJobs(currentUser.uid).listen((jobs) {
      _driverAssignedJobs = jobs;

      // ✅ Cleanup local buffer if job appears in stream
      if (_localAssignedJobs.isNotEmpty) {
        final streamIds = jobs.map((e) => e.id).toSet();
        _localAssignedJobs.removeWhere((local) => streamIds.contains(local.id));
      }

      notifyListeners();
    }, onError: (error) {
      log('JobProvider Error (Driver): $error');
    });

    // 4. ✅ Legacy Listen (For tasks that only have driver_id)
    _legacyJobsSubscription =
        _jobService.getLegacyDriverAssignedJobs(currentUser.uid).listen((jobs) {
      _legacyAssignedJobs = jobs;
      notifyListeners();
    }, onError: (error) {
      log('JobProvider Error (Legacy): $error');
    });
  }

  Future<void> createNewJob(Job job) async {
    try {
      await _jobService.createJob(job);
    } catch (e) {
      log('Provider Error creating job: $e');
      rethrow;
    }
  }

  Future<void> claimJob(String jobId, String driverUid) async {
    try {
      await _jobService.claimJob(jobId, driverUid);
    } catch (e) {
      log('Provider Error claiming job: $e');
      rethrow;
    }
  }

  Future<void> completeJob(
      String jobId,
      String driverUid,
      String proofImage,
      firestore.GeoPoint proofLocation,
      List<Map<String, dynamic>> deliveryTeamData,
      {double? collectedCod,
      String? customerId,
      int? orderId}) async {
    try {
      // Check Connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      bool isOffline = connectivityResult.contains(ConnectivityResult.none);

      if (isOffline) {
        log('JobProvider: Offline detected. Saving job locally.');

        final jobData = {
          'jobId': jobId,
          'driverUid': driverUid,
          'localImagePath':
              proofImage, // Assuming proofImage is local path here
          'lat': proofLocation.latitude,
          'lng': proofLocation.longitude,
          'timestamp': DateTime.now().toIso8601String(),
          'deliveryTeam': deliveryTeamData,
          if (collectedCod != null) 'collectedCod': collectedCod,
          if (customerId != null) 'customerId': customerId,
          if (orderId != null) 'orderId': orderId,
        };

        await SyncService().saveOfflineJob(jobData);

        // Optimistic Update: Update local state immediately so UI reflects change
        final index = _driverAssignedJobs.indexWhere((j) => j.id == jobId);
        if (index != -1) {
          final updatedJob = _driverAssignedJobs[index].copyWith(
            status: 'completed',
            proofImage: proofImage,
            proofLocation: proofLocation,
            completedAt: DateTime.now(),
          );
          _driverAssignedJobs[index] = updatedJob;
          notifyListeners();
        }

        return;
      }

      // Online: Call POS API to cut debt if COD collected
      // ✅ Fail Gracefully: ปิดงานได้เสมอ แม้ตัดหนี้ไม่สำเร็จ
      bool codDebtSuccess = true;
      String? codDebtError;

      if (collectedCod != null && collectedCod > 0) {
        try {
          // ✅ ถ้าไม่มี customerId (Firebase UID) ให้ใช้แค่ orderId เป็น fallback
          // DebtController ฝั่ง backend มี fallback ดึง customerId จาก orderId
          final success = await PosApiService().payCodDebt(
            jobId: jobId,
            customerId: customerId ??
                '', // ส่ง empty ถ้า null → backend ใช้ orderId แทน
            amount: collectedCod,
            driverId: driverUid,
            orderId: orderId,
          );
          if (!success) {
            codDebtSuccess = false;
            codDebtError =
                'API ตอบกลับ false (อาจ customerId หรือ orderId ไม่ถูกต้อง)';
            log('⚠️ COD Debt failed for Job $jobId — orderId: $orderId, customerId: $customerId, amount: $collectedCod');
          }
        } catch (e) {
          codDebtSuccess = false;
          codDebtError = e.toString();
          log('⚠️ COD Debt error for Job $jobId: $e');
        }
      }

      // ✅ ปิดงานเสมอ ไม่ว่า COD debt จะสำเร็จหรือไม่
      await _jobService.completeJob(jobId,
          driverUid: driverUid,
          proofImage: proofImage,
          proofLocation: proofLocation,
          deliveryTeamData: deliveryTeamData,
          collectedCod: collectedCod);



      // ✅ แจ้ง POS Backend ให้บันทึกลง MySQL โดยตรง (เพื่อใช้ใน Delivery Report)
      _notifyPosBackend(
        jobId: jobId,
        orderId: orderId,
        deliveryTeamData: deliveryTeamData,
        proofLocation: proofLocation,
        collectedCod: collectedCod,
      ).catchError((e) =>
          log('⚠️ [JobProvider] บันทึก POS backend ไม่สำเร็จ (ไม่กระทบต่อการปิดงาน): $e'));

      // ✅ หลังปิดงานแล้ว ค่อย throw error ถ้า COD fail (UI จะ show warning แต่งานปิดแล้ว)
      if (!codDebtSuccess) {
        // ไม่ rethrow แต่ log ไว้ — ให้ admin ไปแก้ manual
        log('⚠️ Job $jobId ปิดสำเร็จแล้ว แต่ตัดหนี้ COD ไม่สำเร็จ: $codDebtError');
      }
    } catch (e) {
      log('Provider Error completing job: $e');
      rethrow; // ✅ Rethrow so UI can show error
    }
  }

  /// ✅ แจ้ง POS Backend (fire-and-forget) เพื่อบันทึกลง delivery_history MySQL
  Future<void> _notifyPosBackend({
    required String jobId,
    int? orderId,
    required List<Map<String, dynamic>> deliveryTeamData,
    required firestore.GeoPoint proofLocation,
    double? collectedCod,
  }) async {
    try {
      // ดึงข้อมูล Job จาก Firestore เพื่อเอา customer / price
      final doc = await firestore.FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .get();

      if (!doc.exists) return;
      final data = doc.data()!;

      final customer = data['customer'] as Map<String, dynamic>? ?? {};
      final double totalAmount =
          (data['price'] as num?)?.toDouble() ?? collectedCod ?? 0.0;

      // สกัด driver / vehicle จาก delivery_team
      List<String> drivers = [];
      String vehiclePlate = '';
      for (var m in deliveryTeamData) {
        if (m['type'] != 'car') {
          final name = m['name']?.toString() ?? '';
          if (name.isNotEmpty) drivers.add(name);
        }
        if (m['type'] == 'car' && vehiclePlate.isEmpty) {
          vehiclePlate =
              m['vehicle_plate']?.toString() ?? m['name']?.toString() ?? '';
        }
      }
      String driverName = drivers.join(', ');

      final body = jsonEncode({
        'orderId': orderId ?? data['localOrderId'] ?? data['order_id'] ?? 0,
        'firebaseJobId': jobId,
        'driverName': driverName,
        'vehiclePlate': vehiclePlate,
        'customerName': customer['name'] ?? '',
        'customerPhone': customer['phoneNumber'] ?? customer['phone'] ?? '',
        'customerAddress': customer['address'] ?? '',
        'totalAmount': totalAmount,
        'jobType': data['job_type'] ?? 'delivery',
        'note': data['details'] ?? '',
        'latitude': proofLocation.latitude,
        'longitude': proofLocation.longitude,
      });

      final result = await PosApiService().postRaw('/jobs/complete', body);
      log('✅ [JobProvider] POS Backend บันทึก delivery_history: $result');
    } catch (e) {
      log('⚠️ [JobProvider] _notifyPosBackend error: $e');
      rethrow;
    }
  }

  Future<void> completePickupJob(String jobId, String staffUid) async {
    try {
      await _jobService.completePickupJob(jobId, staffUid);
    } catch (e) {
      log('Provider Error completing pickup job: $e');
      rethrow;
    }
  }

  Future<void> deleteJob(String jobId) async {
    await _jobService.deleteJob(jobId);
  }

  Future<void> updateJob(String jobId, Map<String, dynamic> updates) async {
    try {
      await firestore.FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .update(updates);
      notifyListeners();
    } catch (e) {
      log('Provider Error updating job: $e');
      rethrow;
    }
  }

  Future<void> approveJobDeparture(String jobId,
      {String? driverId,
      List<String>? driverIds,
      List<String>? vehicleIds,
      List<DeliveryTeamItem>? deliveryTeam}) async {
    try {
      final Map<String, dynamic> updates = {'is_departure_approved': true};

      if (driverIds != null && driverIds.isNotEmpty) {
        updates['driver_ids'] = driverIds;
        updates['driver_id'] = driverIds.first; // Sync primary driver
      } else if (driverId != null && driverId.isNotEmpty) {
        updates['driver_id'] = driverId;
        updates['driver_ids'] = [driverId];
      }

      if (vehicleIds != null && vehicleIds.isNotEmpty) {
        updates['vehicle_ids'] = vehicleIds;
      }

      if (deliveryTeam != null && deliveryTeam.isNotEmpty) {
        updates['delivery_team'] = deliveryTeam.map((e) => e.toJson()).toList();
      }

      // Optimistic Update: Update local state immediately
      // This prevents the job from "disappearing" from the list while waiting for Firestore Stream
      // 1. Find the job in pending or current lists
      Job? jobToUpdate;
      var sourceList = _pendingJobs;
      var index = sourceList.indexWhere((j) => j.id == jobId);

      if (index == -1) {
        sourceList = _driverAssignedJobs;
        index = sourceList.indexWhere((j) => j.id == jobId);
      }

      if (index != -1) {
        jobToUpdate = sourceList[index];

        final List<String> newDriverIds = driverIds ??
            (driverId != null ? [driverId] : jobToUpdate.driverIds);
        final String? newDriverId =
            newDriverIds.isNotEmpty ? newDriverIds.first : jobToUpdate.driverId;

        final updatedJob = jobToUpdate.copyWith(
          isDepartureApproved: true,
          driverIds: newDriverIds,
          driverId: newDriverId,
          vehicleIds: vehicleIds ?? jobToUpdate.vehicleIds,
          deliveryTeam: deliveryTeam ?? jobToUpdate.deliveryTeam,
        );

        // ✅ IMPORTANT: Update the job in the source list (e.g. pendingJobs)
        sourceList[index] = updatedJob;

        // Check if we need to add to _driverAssignedJobs
        final assignedIndex =
            _driverAssignedJobs.indexWhere((j) => j.id == jobId);
        if (assignedIndex != -1) {
          _driverAssignedJobs[assignedIndex] = updatedJob;
        } else {
          final myUid = _currentUser?.uid;
          if (myUid != null && newDriverIds.contains(myUid)) {
            _driverAssignedJobs.add(updatedJob);
            _localAssignedJobs.add(updatedJob);
            _driverAssignedJobs
                .sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }
        }

        notifyListeners();
        // ✅ Line Notification ถูกจัดการโดย Cloud Functions โดยตรงแล้ว (ไม่ต้องส่งจากที่นี่)
      }

      await firestore.FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .update(updates);


    } catch (e) {
      log('Provider Error approving departure: $e');
      rethrow;
    }
  }

  Future<int> deleteExportedCompletedJobs() async {
    try {
      final deletedCount = await _jobService.deleteAllCompletedJobs();

      if (deletedCount > 0) {
        notifyListeners();
      }
      return deletedCount;
    } catch (e) {
      log('Provider Error deleting all completed jobs: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    stopListening();

    super.dispose();
  }
}
