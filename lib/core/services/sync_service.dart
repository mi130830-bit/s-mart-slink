import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:s_link/features/pos/services/pos_api_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();

  factory SyncService() {
    return _instance;
  }

  SyncService._internal();

  static const String _offlineJobsKey = 'offline_completed_jobs';
  bool _isSyncing = false;

  /// Listen for connectivity changes and trigger sync when online
  void startMonitoring() {
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi)) {
        log('SyncService: Online! Checking for pending jobs...');
        syncPendingJobs();
      }
    });
  }

  /// Save a job completion locally when offline
  Future<void> saveOfflineJob(Map<String, dynamic> jobData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> offlineJobs = prefs.getStringList(_offlineJobsKey) ?? [];

      // ✅ Persistence: Copy image to permanent directory (outside of temp)
      final String originalPath = jobData['localImagePath'];
      if (originalPath.isNotEmpty) {
        final File originalFile = File(originalPath);
        if (await originalFile.exists()) {
          final directory = await getApplicationDocumentsDirectory();
          final String fileName = p.basename(originalPath);
          final String permanentPath =
              p.join(directory.path, 'offline_proofs', fileName);

          // Ensure directory exists
          await Directory(p.dirname(permanentPath)).create(recursive: true);

          await originalFile.copy(permanentPath);
          jobData['localImagePath'] = permanentPath; // Update to permanent path
          log('SyncService: Image persistent at $permanentPath');
        }
      }

      // Store locally
      offlineJobs.add(jsonEncode(jobData));

      await prefs.setStringList(_offlineJobsKey, offlineJobs);
      log('SyncService: Job saved offline. Queue size: ${offlineJobs.length}');
    } catch (e) {
      log('SyncService Error saving offline job: $e');
    }
  }

  /// Process the offline queue
  Future<void> syncPendingJobs() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? offlineJobs = prefs.getStringList(_offlineJobsKey);

      if (offlineJobs == null || offlineJobs.isEmpty) {
        log('SyncService: No pending jobs to sync.');
        _isSyncing = false;
        return;
      }

      log('SyncService: Syncing ${offlineJobs.length} jobs...');
      List<String> failedJobs = [];

      for (String jobJson in offlineJobs) {
        try {
          final jobData = jsonDecode(jobJson);
          await _processJob(jobData);
        } catch (e) {
          log('SyncService: Failed to sync job: $e');
          // If permanent error, maybe move to "failed" list or retry later
          // For now, keep in failed list to retry
          failedJobs.add(jobJson);
        }
      }

      // Update the list with only the failed ones (or empty if all success)
      await prefs.setStringList(_offlineJobsKey, failedJobs);
      log('SyncService: Sync completed. Remaining failed jobs: ${failedJobs.length}');
    } catch (e) {
      log('SyncService: Error during sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processJob(Map<String, dynamic> data) async {
    final String jobId = data['jobId'];
    final String localImagePath = data['localImagePath'];
    final String driverUid = data['driverUid'];
    final double lat = data['lat'];
    final double lng = data['lng'];
    // final List<dynamic> deliveryTeam = data['deliveryTeam']; // Determine how to handle complex types if needed

    log('SyncService: Uploading image for Job $jobId...');

    // 1. Upload Image
    final File imageFile = File(localImagePath);
    if (!imageFile.existsSync()) {
      throw Exception('Local image file not found: $localImagePath');
    }

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('proof_images')
        .child('$jobId.jpg');

    await storageRef.putFile(imageFile);
    final String downloadUrl = await storageRef.getDownloadURL();

    // 2. Update Firestore
    log('SyncService: Updating Firestore for Job $jobId...');
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'status': 'completed',
      'proof_image': downloadUrl,
      'proof_location': GeoPoint(lat, lng),
      'completed_at': FieldValue.serverTimestamp(),
      'driver_id': driverUid,
      if (data['deliveryTeam'] != null) 'delivery_team': data['deliveryTeam'],
      if (data['collectedCod'] != null && data['collectedCod'] > 0)
        'collected_cod': data['collectedCod'],
    });

    // 3. API Call Sync (COD to Desktop)
    if (data['collectedCod'] != null &&
        data['collectedCod'] > 0 &&
        data['customerId'] != null) {
      log('SyncService: Syncing COD payment to POS API...');
      final success = await PosApiService().payCodDebt(
        jobId: jobId,
        customerId: data['customerId'],
        amount: data['collectedCod'],
        driverId: driverUid,
      );
      if (!success) {
        throw Exception('Failed to sync COD payment to backend API.');
      }
      log('SyncService: COD sync successful.');
    }

    // 4. Cleanup: Delete local image file
    try {
      if (imageFile.existsSync()) {
        await imageFile.delete();
        log('SyncService: Local image deleted for Job $jobId');
      }
    } catch (e) {
      log('SyncService: Error deleting local file (non-critical): $e');
    }

    log('SyncService: Job $jobId Synced Successfully!');
  }
}
