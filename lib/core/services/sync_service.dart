import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:s_link/core/database/local_db_service.dart';
import 'package:s_link/features/jobs/repositories/local_job_repository.dart';
import 'package:s_link/features/pos/services/pos_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  static const String _tag = '[SyncService]';
  static const String _lastSyncKey = 'jobs_last_sync_at';
  static const String _legacyOfflineKey = 'offline_completed_jobs';

  bool _isSyncing = false;
  final _localRepo = LocalJobRepository();

  // ═══════════════════════════════════════════════════════
  // CONNECTIVITY MONITOR
  // ═══════════════════════════════════════════════════════

  void startMonitoring() {
    log('$_tag Connectivity monitor started');
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final isOnline = results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi);
      if (isOnline) {
        log('$_tag Online! Triggering sync...');
        syncJobsDown()
            .then((_) => syncPendingJobs())
            .catchError((e) => log('$_tag Auto-sync error: $e'));
      }
    });
  }

  // ═══════════════════════════════════════════════════════
  // SYNC DOWN (API -> Local SQLite)
  // ═══════════════════════════════════════════════════════

  Future<int> syncJobsDown({bool forceFullSync = false}) async {
    final tag = '$_tag[syncDown]';
    log('$tag Starting (forceFullSync=$forceFullSync)...');

    try {
      final prefs = await SharedPreferences.getInstance();
      String? since;
      if (!forceFullSync) {
        since = prefs.getString(_lastSyncKey);
        if (since != null) log('$tag Delta sync since: $since');
      }

      final apiJobs = await PosApiService().getActiveJobs(since: since);
      log('$tag API returned ${apiJobs.length} jobs');

      if (apiJobs.isEmpty) {
        log('$tag No new jobs to sync down');
        return 0;
      }

      await _localRepo.syncFromApi(apiJobs);
      await prefs.setString(_lastSyncKey, DateTime.now().toUtc().toIso8601String());
      log('$tag Sync complete: ${apiJobs.length} jobs saved');

      final cleaned = await _localRepo.cleanupOldJobs();
      if (cleaned > 0) log('$tag Auto-cleanup: removed $cleaned old jobs');

      return apiJobs.length;
    } catch (e, stack) {
      log('$tag ERROR: $e\n$stack');
      return 0;
    }
  }

  // ═══════════════════════════════════════════════════════
  // SAVE OFFLINE JOB (Local-first)
  // ═══════════════════════════════════════════════════════

  Future<void> saveOfflineJob(Map<String, dynamic> jobData) async {
    final tag = '$_tag[saveOffline]';
    try {
      final String originalPath = jobData['localImagePath'] ?? '';

      if (originalPath.isNotEmpty) {
        final File originalFile = File(originalPath);
        if (await originalFile.exists()) {
          final directory = await getApplicationDocumentsDirectory();
          final String fileName = p.basename(originalPath);
          final String permanentPath = p.join(directory.path, 'offline_proofs', fileName);
          await Directory(p.dirname(permanentPath)).create(recursive: true);
          await originalFile.copy(permanentPath);
          jobData['localImagePath'] = permanentPath;
          log('$tag Image moved to: $permanentPath');
        } else {
          log('$tag WARNING: Image file not found at $originalPath');
        }
      }

      await _localRepo.enqueueOfflineJob(jobData);

      final orderId = int.tryParse(jobData['orderId']?.toString() ?? '');
      if (orderId != null) {
        await LocalDbService().markJobCompleted(
          orderId: orderId,
          proofImagePath: jobData['localImagePath'] ?? '',
          proofLat: (jobData['lat'] as num?)?.toDouble() ?? 0.0,
          proofLng: (jobData['lng'] as num?)?.toDouble() ?? 0.0,
        );
        log('$tag Local job orderId=$orderId marked as completed (pending sync)');
      }

      log('$tag Offline job saved to SQLite queue successfully');
    } catch (e) {
      log('$tag ERROR: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // SYNC UP (SQLite Queue -> API + Firebase)
  // ═══════════════════════════════════════════════════════

  Future<void> syncPendingJobs() async {
    if (_isSyncing) {
      log('$_tag Already syncing, skipping...');
      return;
    }
    _isSyncing = true;

    try {
      await _migrateLegacyQueue();

      final pending = await _localRepo.getPendingSyncItems();
      if (pending.isEmpty) {
        log('$_tag No pending sync items.');
        return;
      }

      log('$_tag Processing ${pending.length} pending items...');

      for (final item in pending) {
        final int id = item['id'] as int;
        final int retryCount = (item['retryCount'] as int?) ?? 0;
        final int? orderId = item['orderId'] as int?;

        if (retryCount >= 5) {
          log('$_tag item id=$id (jobId=${item['jobId']}) failed 5+ times. Marking as failed.');
          await _localRepo.markSyncItemStatus(id, 'failed');
          continue;
        }

        try {
          await _localRepo.markSyncItemStatus(id, 'uploading');
          await _processQueueItem(item);
          await _localRepo.removeSyncItem(id);
          if (orderId != null) await _localRepo.deleteJob(orderId);
          log('$_tag item id=$id synced and cleaned up');
        } catch (e) {
          log('$_tag item id=$id failed (attempt ${retryCount + 1}/5): $e');
          await _localRepo.markSyncItemStatus(id, 'pending');
        }
      }
    } catch (e) {
      log('$_tag ERROR in syncPendingJobs: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processQueueItem(Map<String, dynamic> data) async {
    final tag = '$_tag[processQueue]';
    final String jobId          = data['jobId']?.toString() ?? '';
    final String localImagePath = data['proofImagePath']?.toString() ?? '';
    final String driverUid      = data['driverUid']?.toString() ?? '';
    final double lat            = (data['proofLat'] as num?)?.toDouble() ?? 0.0;
    final double lng            = (data['proofLng'] as num?)?.toDouble() ?? 0.0;

    log('$tag Processing jobId=$jobId, orderId=${data['orderId']}, retry=${data['retryCount']}');

    // Step 1: Upload image to Firebase Storage
    String downloadUrl = '';
    final File imageFile = File(localImagePath);
    if (imageFile.existsSync()) {
      log('$tag Uploading proof image...');
      final storageRef = FirebaseStorage.instance.ref().child('proof_images').child('$jobId.jpg');
      await storageRef.putFile(imageFile);
      downloadUrl = await storageRef.getDownloadURL();
      log('$tag Image uploaded: $downloadUrl');
    } else {
      log('$tag WARNING: Image not found at $localImagePath, continuing without image');
    }

    // Step 2: COD Payment
    final double? collectedCod = (data['collectedCod'] as num?)?.toDouble();
    if (collectedCod != null && collectedCod > 0) {
      log('$tag Syncing COD payment: $collectedCod baht');
      try {
        final success = await PosApiService().payCodDebt(
          jobId: jobId,
          customerId: data['customerId']?.toString() ?? '',
          amount: collectedCod,
          driverId: driverUid,
          orderId: data['orderId'] as int?,
        );
        log('$tag COD: ${success ? "SUCCESS" : "FAILED"}');
      } catch (e) {
        log('$tag COD error (non-fatal): $e');
      }
    }

    // Step 3: Notify POS Backend (save delivery_history)
    log('$tag Sending delivery_history to POS Backend...');
    final body = jsonEncode({
      'orderId':         data['orderId'],
      'firebaseJobId':   jobId,
      'driverName':      data['driverName'] ?? '',
      'vehiclePlate':    data['vehiclePlate'] ?? '',
      'customerName':    data['customerName'] ?? '',
      'customerPhone':   data['customerPhone'] ?? '',
      'customerAddress': data['customerAddress'] ?? '',
      'totalAmount':     data['totalAmount'] ?? 0,
      'jobType':         data['jobType'] ?? 'delivery',
      'note':            '',
      'latitude':        lat,
      'longitude':       lng,
      'billImageUrl':    downloadUrl,
    });
    await PosApiService().postRaw('/jobs/complete', body);
    log('$tag POS Backend notified');

    // Step 4: Update Firebase as signal only
    if (jobId.isNotEmpty) {
      log('$tag Updating Firebase signal...');
      try {
        await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
          'status':       'completed',
          'completed_at': FieldValue.serverTimestamp(),
          'driver_id':    driverUid,
          if (collectedCod != null && collectedCod > 0) 'collected_cod': collectedCod,
        });
        log('$tag Firebase signal updated');
      } catch (e) {
        log('$tag Firebase signal update failed (non-fatal, data is in MySQL): $e');
      }
    }

    // Step 5: Delete local image file
    if (downloadUrl.isNotEmpty && imageFile.existsSync()) {
      try {
        await imageFile.delete();
        log('$tag Local proof image deleted after successful upload');
      } catch (e) {
        log('$tag Could not delete local image (non-fatal): $e');
      }
    }

    log('$tag Job $jobId processed successfully!');
  }

  // ═══════════════════════════════════════════════════════
  // MIGRATION: SharedPreferences -> SQLite
  // ═══════════════════════════════════════════════════════

  Future<void> _migrateLegacyQueue() async {
    final tag = '$_tag[migration]';
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getStringList(_legacyOfflineKey);
      if (legacy == null || legacy.isEmpty) return;

      log('$tag Found ${legacy.length} legacy jobs. Migrating to SQLite...');
      for (final jobJson in legacy) {
        try {
          final data = jsonDecode(jobJson) as Map<String, dynamic>;
          await _localRepo.enqueueOfflineJob(data);
        } catch (e) {
          log('$tag Migration error for item: $e');
        }
      }

      await prefs.remove(_legacyOfflineKey);
      log('$tag Migration complete. Legacy queue cleared.');
    } catch (e) {
      log('$tag Migration failed (non-fatal): $e');
    }
  }
}
