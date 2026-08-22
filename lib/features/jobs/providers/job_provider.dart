// ไฟล์: lib/features/jobs/providers/job_provider.dart
// [Milestone 2] ปรับให้อ่านงาน active จาก LocalJobRepository (SQLite) แทน Firebase

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

import 'package:s_link/core/services/sync_service.dart';
import 'package:s_link/features/jobs/repositories/local_job_repository.dart';
import 'package:s_link/features/jobs/services/job_service.dart';
import 'package:s_link/features/pos/services/pos_api_service.dart';

import 'package:s_link/core/services/notification_service.dart';
import 'package:s_link/features/jobs/models/job.dart';
import 'package:s_link/features/auth/models/user.dart';

class JobProvider with ChangeNotifier {
  final JobService _jobService;
  final _localRepo = LocalJobRepository();

  // [M2] Active jobs ตอนนี้มาจาก Local SQLite
  List<Job> _activeLocalJobs = [];

  // Firebase Stream สำหรับงาน pending (ยังคงไว้เพื่อรับ notification)
  StreamSubscription? _pendingJobsSubscription;
  StreamSubscription? _driverAssignedJobsSubscription;
  StreamSubscription? _legacyJobsSubscription;

  List<Job> _pendingJobs = [];
  List<Job> _completedJobs = [];
  List<Job> _statsJobs = [];
  List<Job> _driverAssignedJobs = [];
  List<Job> _legacyAssignedJobs = [];
  List<Job> _localAssignedJobs = [];
  Map<String, dynamic> _summaryStats = {};
  bool _isLoading = false;
  bool _isSyncingDown = false;
  String? _pendingJobsError;
  UserModel? _currentUser;

  List<Job> get pendingJobs => _pendingJobs;
  List<Job> get completedJobs => _completedJobs;
  List<Job> get statsJobs => _statsJobs;
  List<Job> get activeLocalJobs => _activeLocalJobs;
  String? get pendingJobsError => _pendingJobsError;
  Map<String, dynamic> get summaryStats => _summaryStats;
  bool get isSyncingDown => _isSyncingDown;

  // Merge the local cache with Firestore assignment streams. The cache does
  // not always include assignment/approval fields, so it must never replace
  // the live data used to decide which jobs belong to a driver.
  List<Job> get driverAssignedJobs {
    final Map<String, Job> jobMap = {};

    // Keep locally saved assignments available offline, but only for this
    // driver. Never expose every active cached job to a driver.
    for (final job in _activeLocalJobs) {
      if (_isAssignedToCurrentUser(job)) jobMap[job.id] = job;
    }

    // Firestore is authoritative for assignment and departure approval.
    // These overwrite the cache when both sources contain the same job.
    for (final job in _legacyAssignedJobs) {
      jobMap[job.id] = job;
    }
    for (final job in _driverAssignedJobs) {
      jobMap[job.id] = job;
    }
    for (final job in _pendingJobs) {
      if (_isAssignedToCurrentUser(job)) jobMap[job.id] = job;
    }
    for (final job in _localAssignedJobs) {
      jobMap[job.id] = job;
    }

    final merged = jobMap.values.where((j) => j.status != 'completed').toList();
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    log('[JobProvider] Serving ${merged.length} assigned jobs');
    return merged;
  }

  bool _isAssignedToCurrentUser(Job job) {
    final ids = _currentAssignmentIds;
    if (ids.isEmpty) return false;
    return (job.driverId != null && ids.contains(job.driverId)) ||
        job.driverIds.any(ids.contains) ||
        job.deliveryTeam.any((member) => ids.contains(member.id));
  }

  Set<String> get _currentAssignmentIds => {
        if (_currentUser?.uid.isNotEmpty == true) _currentUser!.uid,
        if (_currentUser?.employeeId?.isNotEmpty == true)
          _currentUser!.employeeId!,
      };

  bool get isLoading => _isLoading;

  Future<void> _persistAssignedJobsToCache(List<Job> jobs) async {
    final ownerUid = _currentUser?.uid;
    if (ownerUid == null || ownerUid.isEmpty) return;
    for (final job in jobs) {
      if (!_isAssignedToCurrentUser(job) || job.localOrderId == null) continue;
      await _localRepo.updateOfflineAssignment(
        job.localOrderId!,
        job.isDepartureApproved,
        job.driverIds,
        job.vehicleIds ?? const [],
        job.deliveryTeam.map((member) => member.toJson()).toList(),
        ownerUid,
      );
    }
  }

  JobProvider(this._jobService) {
    SyncService().onSyncComplete.listen((_) {
      loadLocalJobs();
    });
  }

  // ═══════════════════════════════════════════════════════
  // [M2] LOAD FROM LOCAL DB
  // ═══════════════════════════════════════════════════════

  /// โหลดงานจาก Local SQLite เพื่อแสดงผลแบบออฟไลน์
  Future<void> loadLocalJobs() async {
    log('[JobProvider] Loading active jobs from Local SQLite...');
    try {
      final ownerUid = _currentUser?.uid;
      if (ownerUid == null || ownerUid.isEmpty) {
        _activeLocalJobs = [];
        return;
      }
      _activeLocalJobs = await _localRepo.getActiveJobs(ownerUid);
      log('[JobProvider] Loaded ${_activeLocalJobs.length} jobs from local DB');
      notifyListeners();
    } catch (e) {
      log('[JobProvider] ERROR loading local jobs: $e');
    }
  }

  /// [M2] Sync งานจาก API ลง SQLite แล้ว reload
  Future<void> syncAndRefreshJobs({bool forceFullSync = false}) async {
    if (_isSyncingDown) {
      log('[JobProvider] Already syncing, skipping...');
      return;
    }
    _isSyncingDown = true;
    notifyListeners();

    try {
      log('[JobProvider][syncDown] Starting download from POS Backend...');
      final count =
          await SyncService().syncJobsDown(forceFullSync: forceFullSync);
      log('[JobProvider][syncDown] Downloaded $count jobs. Refreshing local view...');
      await loadLocalJobs();
    } catch (e) {
      log('[JobProvider][syncDown] ERROR: $e');
    } finally {
      _isSyncingDown = false;
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════
  // EXISTING FUNCTIONS (ยังคงไว้สำหรับ Admin/Requester views)
  // ═══════════════════════════════════════════════════════

  void stopListening() {
    log('[JobProvider] Stopping all listeners...');
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
    _localAssignedJobs = [];
    _activeLocalJobs = [];
    _isLoading = false;
    _pendingJobsError = null;

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
      log('[JobProvider] Fetched ${_completedJobs.length} completed jobs');
    } catch (e) {
      log('[JobProvider] Error fetching completed jobs: $e');
      _completedJobs = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSummaryStats() async {
    try {
      _isLoading = true;
      notifyListeners();
      final response = await PosApiService().getJobSummaryStats();
      if (response != null && response['success'] == true) {
        _summaryStats = response;
        log('[JobProvider] Summary Stats Loaded: ${response['totalJobs']} jobs');
      }
    } catch (e) {
      log('[JobProvider] fetchSummaryStats Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchJobStats({int limit = 100}) async {
    try {
      _isLoading = true;
      notifyListeners();
      final now = DateTime.now();
      final sixtyDaysAgo = now.subtract(const Duration(days: 60));
      final history = await PosApiService()
          .getDeliveryHistory(startDate: sixtyDaysAgo, endDate: now);
      _statsJobs = history.map((m) => Job.fromHistory(m)).toList();
      log('[JobProvider] Fetched ${_statsJobs.length} jobs from MySQL history');
    } catch (e) {
      log('[JobProvider] Error fetching stats: $e');
      _statsJobs = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshStreams() async {
    log('[JobProvider] Manual Refresh Requested');
    stopListening();
    if (_currentUser != null) startListeningToJobs(_currentUser);
    notifyListeners();
  }

  void startListeningToJobs(UserModel? currentUser) {
    if (currentUser == null) return;
    _currentUser = currentUser;
    SyncService().setActiveUser(currentUser.uid);

    // [M2] เริ่ม monitor connectivity สำหรับ auto-sync
    SyncService().startMonitoring();

    stopListening();
    _isLoading = true;
    notifyListeners();

    final role = currentUser.role.name.toLowerCase();
    NotificationService.initialize();

    // [M2] โหลดงานจาก Local DB ทันที (ออฟไลน์ได้เลย)
    _localRepo
        .claimUnownedRecords(currentUser.uid)
        .then((_) => loadLocalJobs())
        .then((_) {
      // จากนั้น sync จาก API เพื่ออัปเดต (ถ้ามีเน็ต)
      syncAndRefreshJobs();
    });

    // Firebase Stream ยังคงไว้เพื่อรับ Push Notification งานใหม่
    _pendingJobsSubscription =
        _jobService.getJobsByStatus('pending').listen((jobs) {
      // Check for new jobs → แจ้งเตือน + trigger syncDown
      if (_pendingJobs.isNotEmpty && jobs.length > _pendingJobs.length) {
        final newCount = jobs.length - _pendingJobs.length;
        NotificationService.showLocalNotification(
          title: 'มีงานส่งของใหม่!',
          body: 'มีงานใหม่เข้ามา $newCount งาน',
        );
        // [M2] Trigger sync เพื่อดึงข้อมูลบิลล่าสุดมาเก็บในมือถือ
        log('[JobProvider] New job detected in Firebase, triggering syncDown...');
        syncAndRefreshJobs();
      }

      _pendingJobs = jobs;
      _pendingJobsError = null;
      _isLoading = false;
      notifyListeners();
    }, onError: (e, stack) {
      log('[JobProvider] CRITICAL Firebase error: $e\n$stack');
      _pendingJobsError = e.toString();
      _isLoading = false;
      notifyListeners();
    });

    if (role == 'admin' || role == 'requester') {
      final today = DateTime.now();
      fetchCompletedJobsByRange(today, today);
    }

    final assignmentIds = _currentAssignmentIds.toList();
    _driverAssignedJobsSubscription =
        _jobService.getDriverAssignedJobs(assignmentIds).listen((jobs) {
      _driverAssignedJobs = jobs;
      _persistAssignedJobsToCache(jobs).catchError(
        (error) =>
            log('[JobProvider] Failed to cache driver assignments: $error'),
      );
      if (_localAssignedJobs.isNotEmpty) {
        final streamIds = jobs.map((e) => e.id).toSet();
        _localAssignedJobs.removeWhere((local) => streamIds.contains(local.id));
      }
      notifyListeners();
    }, onError: (error) {
      log('[JobProvider] Firebase Driver stream error: $error');
    });

    _legacyJobsSubscription =
        _jobService.getLegacyDriverAssignedJobs(assignmentIds).listen((jobs) {
      _legacyAssignedJobs = jobs;
      _persistAssignedJobsToCache(jobs).catchError(
        (error) =>
            log('[JobProvider] Failed to cache legacy assignments: $error'),
      );
      notifyListeners();
    }, onError: (error) {
      log('[JobProvider] Firebase Legacy stream error: $error');
    });
  }

  // ═══════════════════════════════════════════════════════
  // JOB ACTIONS
  // ═══════════════════════════════════════════════════════

  Future<void> createNewJob(Job job) async {
    try {
      await _jobService.createJob(job);
    } catch (e) {
      log('[JobProvider] Error creating job: $e');
      rethrow;
    }
  }

  Future<void> claimJob(String jobId, String driverUid) async {
    try {
      await _jobService.claimJob(jobId, driverUid);
    } catch (e) {
      log('[JobProvider] Error claiming job: $e');
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
      final connectivityResult = await Connectivity().checkConnectivity();
      bool isOffline = connectivityResult.contains(ConnectivityResult.none);

      if (isOffline) {
        log('[JobProvider] OFFLINE: Saving job locally first...');

        // [M2] บันทึกลง Local SQLite ก่อน
        if (orderId != null) {
          await _localRepo.markCompleted(
            orderId: orderId,
            ownerUid: driverUid,
            proofImagePath: proofImage,
            proofLat: proofLocation.latitude,
            proofLng: proofLocation.longitude,
          );
        }

        final jobData = {
          'jobId': jobId,
          'driverUid': driverUid,
          'localImagePath': proofImage,
          'lat': proofLocation.latitude,
          'lng': proofLocation.longitude,
          'timestamp': DateTime.now().toIso8601String(),
          'deliveryTeam': deliveryTeamData,
          if (collectedCod != null) 'collectedCod': collectedCod,
          if (customerId != null) 'customerId': customerId,
          if (orderId != null) 'orderId': orderId,
        };

        await SyncService().saveOfflineJob(jobData, ownerUid: driverUid);

        // Optimistic UI update
        _activeLocalJobs.removeWhere((j) => j.localOrderId == orderId);
        final index = _driverAssignedJobs.indexWhere((j) => j.id == jobId);
        if (index != -1) {
          _driverAssignedJobs[index] = _driverAssignedJobs[index].copyWith(
            status: 'completed',
            proofImage: proofImage,
            proofLocation: proofLocation,
            completedAt: DateTime.now(),
          );
        }
        notifyListeners();
        log('[JobProvider] Offline job saved. Will sync when online.');
        return;
      }

      // ── Online: COD Payment ─────────────────────────────────────────
      bool codDebtSuccess = true;
      String? codDebtError;

      if (collectedCod != null && collectedCod > 0) {
        try {
          final success = await PosApiService().payCodDebt(
            jobId: jobId,
            customerId: customerId ?? '',
            amount: collectedCod,
            driverId: driverUid,
            orderId: orderId,
          );
          if (!success) {
            codDebtSuccess = false;
            codDebtError = 'API returned false';
            log('[JobProvider] COD failed for Job $jobId: $codDebtError');
          }
        } catch (e) {
          codDebtSuccess = false;
          codDebtError = e.toString();
          log('[JobProvider] COD error: $e');
        }
      }

      // ── [M2] บันทึกลง Local SQLite ก่อน (Local-first) ─────────────
      if (orderId != null) {
        await _localRepo.markCompleted(
          orderId: orderId,
          ownerUid: driverUid,
          proofImagePath: proofImage,
          proofLat: proofLocation.latitude,
          proofLng: proofLocation.longitude,
        );
        log('[JobProvider] Job orderId=$orderId marked completed in local DB');
      }

      // ── ส่ง API บันทึก delivery_history ───────────────────────────
      await _notifyPosBackend(
        jobId: jobId,
        orderId: orderId,
        deliveryTeamData: deliveryTeamData,
        proofLocation: proofLocation,
        collectedCod: collectedCod,
        proofImage: proofImage,
      );

      // ── Update Firebase Signal ──────────────────────────────────────
      await _jobService.completeJob(jobId,
          driverUid: driverUid,
          proofImage: proofImage,
          proofLocation: proofLocation,
          deliveryTeamData: deliveryTeamData,
          collectedCod: collectedCod);

      // ── [M2] ลบงานออกจาก Local SQLite หลัง sync สำเร็จ ───────────
      if (orderId != null) {
        await _localRepo.deleteJob(orderId, driverUid);
        _activeLocalJobs.removeWhere((j) => j.localOrderId == orderId);
        notifyListeners();
        log('[JobProvider] Job orderId=$orderId deleted from local DB after successful sync');
      }

      // ── GPS Status Update ────────────────────────────────────────────
      try {
        final vehicleEntry = deliveryTeamData
            .where((e) => e['type'] == 'car' || e['type'] == 'vehicle')
            .firstOrNull;
        final String vehicleNameForGps = vehicleEntry != null
            ? ((vehicleEntry['name']?.toString().trim().isNotEmpty == true
                        ? vehicleEntry['name']
                        : vehicleEntry['licensePlate'])
                    ?.toString() ??
                'ไม่ระบุรถ')
            : 'ไม่ระบุรถ';

        await PosApiService().postRaw('/gps/update_job', {
          'vehicle': vehicleNameForGps,
          'jobStatus': 'กำลังกลับร้าน',
        }).timeout(const Duration(seconds: 3));
      } catch (e) {
        log('[JobProvider] GPS status update failed (non-fatal): $e');
      }

      if (!codDebtSuccess) {
        log('[JobProvider] WARN: Job $jobId completed but COD failed: $codDebtError');
      }
    } catch (e) {
      log('[JobProvider] Error completing job: $e');
      rethrow;
    }
  }

  Future<void> _notifyPosBackend({
    required String jobId,
    int? orderId,
    required List<Map<String, dynamic>> deliveryTeamData,
    required firestore.GeoPoint proofLocation,
    double? collectedCod,
    String? proofImage,
  }) async {
    final tag = '[JobProvider][_notifyPosBackend]';
    try {
      log('$tag Fetching job data from Firestore for jobId=$jobId...');
      final doc = await firestore.FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .get();
      if (!doc.exists) {
        log('$tag Firestore doc not found, building payload from local data...');
      }
      final data = doc.data() ?? {};

      final customer = data['customer'] as Map<String, dynamic>? ?? {};
      final double totalAmount =
          (data['price'] as num?)?.toDouble() ?? collectedCod ?? 0.0;

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

      final body = jsonEncode({
        'orderId': orderId ?? data['localOrderId'] ?? data['order_id'] ?? 0,
        'firebaseJobId': jobId,
        'driverName': drivers.join(', '),
        'vehiclePlate': vehiclePlate,
        'customerName': customer['name'] ?? '',
        'customerPhone': customer['phoneNumber'] ?? customer['phone'] ?? '',
        'customerAddress': customer['address'] ?? '',
        'totalAmount': totalAmount,
        'jobType': data['job_type'] ?? 'delivery',
        'note': data['details'] ?? '',
        'latitude': proofLocation.latitude,
        'longitude': proofLocation.longitude,
        'billImageUrl': proofImage ?? data['proof_image'] ?? '',
      });

      final result = await PosApiService().postRaw('/jobs/complete', body);
      log('$tag POS Backend recorded: $result');
    } catch (e) {
      log('$tag Error: $e');
      rethrow;
    }
  }

  Future<void> completePickupJob(String jobId, String staffUid) async {
    try {
      await _jobService.completePickupJob(jobId, staffUid);
    } catch (e) {
      log('[JobProvider] Error completing pickup job: $e');
      rethrow;
    }
  }

  Future<void> deleteJob(String jobId) async {
    Job? cachedJob;
    for (final job in _activeLocalJobs) {
      if (job.id == jobId) {
        cachedJob = job;
        break;
      }
    }
    if (cachedJob != null) {
      await removeCachedJob(cachedJob);
    }

    await _jobService.deleteJob(jobId);
    notifyListeners();
  }

  /// Remove a stale job from the offline cache. This is used when Firestore
  /// confirms that the job document no longer exists.
  Future<void> removeCachedJob(Job job) async {
    final orderId = job.localOrderId;
    if (orderId != null) {
      final ownerUid = _currentUser?.uid;
      if (ownerUid != null && ownerUid.isNotEmpty) {
        await _localRepo.deleteJob(orderId, ownerUid);
      }
      _activeLocalJobs.removeWhere(
          (cached) => cached.localOrderId == orderId || cached.id == job.id);
    } else {
      _activeLocalJobs.removeWhere((cached) => cached.id == job.id);
    }
    notifyListeners();
  }

  Future<void> updateJob(String jobId, Map<String, dynamic> updates) async {
    try {
      await firestore.FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .update(updates);
      notifyListeners();
    } catch (e) {
      log('[JobProvider] Error updating job: $e');
      rethrow;
    }
  }

  Future<List<String>> uploadJobImages(List<File> images) async {
    List<String> newUrls = [];
    for (var file in images) {
      final String fileName =
          'bills/${DateTime.now().millisecondsSinceEpoch}_${newUrls.length}.jpg';
      final ref =
          firebase_storage.FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(file);
      newUrls.add(await ref.getDownloadURL());
    }
    return newUrls;
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
        updates['driver_id'] = driverIds.first;
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

        sourceList[index] = updatedJob;

        // Save to Local SQLite
        if (updatedJob.localOrderId != null) {
          await _localRepo.updateOfflineAssignment(
            updatedJob.localOrderId!,
            true,
            updatedJob.driverIds,
            updatedJob.vehicleIds ?? [],
            updatedJob.deliveryTeam.map((e) => e.toJson()).toList(),
            _currentUser?.uid ?? '',
          );
        }

        final assignedIndex =
            _driverAssignedJobs.indexWhere((j) => j.id == jobId);
        if (assignedIndex != -1) {
          _driverAssignedJobs[assignedIndex] = updatedJob;
        } else {
          if (newDriverIds.any(_currentAssignmentIds.contains)) {
            _driverAssignedJobs.add(updatedJob);
            _localAssignedJobs.add(updatedJob);
            _driverAssignedJobs
                .sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }
        }

        notifyListeners();
      }

      await firestore.FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .update(updates);

      // GPS Status Update
      try {
        final jobCustomerName = jobToUpdate?.customer.name ?? 'ไม่ระบุชื่อ';
        String teamNames = '';
        final effectiveTeam = deliveryTeam ?? jobToUpdate?.deliveryTeam ?? [];
        if (effectiveTeam.isNotEmpty) {
          final people = effectiveTeam
              .where((e) => e.type != 'vehicle')
              .map((e) => e.name)
              .toList();
          if (people.isNotEmpty) teamNames = ' (${people.join(', ')})';
        }

        final vehicleItemDep = effectiveTeam
            .where((e) => e.type == 'car' || e.type == 'vehicle')
            .firstOrNull;
        final String vehicleNameDep = vehicleItemDep != null
            ? (vehicleItemDep.name.trim().isNotEmpty
                ? vehicleItemDep.name
                : vehicleItemDep.licensePlate ?? 'ไม่ระบุรถ')
            : 'ไม่ระบุรถ';

        await PosApiService().postRaw('/gps/update_job', {
          'vehicle': vehicleNameDep,
          'jobStatus': 'กำลังส่งของ: $jobCustomerName$teamNames',
        }).timeout(const Duration(seconds: 3));
      } catch (e) {
        log('[JobProvider] GPS status update failed (non-fatal): $e');
      }
    } catch (e) {
      log('[JobProvider] Error approving departure: $e');
      rethrow;
    }
  }

  Future<int> deleteExportedCompletedJobs() async {
    try {
      final deletedCount = await _jobService.deleteAllCompletedJobs();
      if (deletedCount > 0) notifyListeners();
      return deletedCount;
    } catch (e) {
      log('[JobProvider] Error deleting all completed jobs: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
