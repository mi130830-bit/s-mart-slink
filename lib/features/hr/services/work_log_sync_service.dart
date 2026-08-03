import 'dart:convert';
import 'package:isar/isar.dart';
import 'package:s_link/features/hr/models/shop_work_log_isar.dart';
import 'package:s_link/services/isar_service.dart';
import 'package:s_link/features/pos/services/pos_api_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer';

class WorkLogSyncService {
  final IsarService _isarService;
  final PosApiService _apiService = PosApiService();
  final Uuid _uuid = const Uuid();

  WorkLogSyncService(this._isarService);

  // 1. Add Log Locally
  Future<void> addWorkLog(String delivererId, List<WorkItemIsar> items) async {
    final isar = await _isarService.db;
    
    final newLog = ShopWorkLogIsar()
      ..syncId = _uuid.v4()
      ..delivererId = delivererId
      ..loggedAt = DateTime.now()
      ..items = items
      ..isSynced = false
      ..isDeleted = false;

    await isar.writeTxn(() async {
      await isar.shopWorkLogIsars.put(newLog);
    });

    log('Saved work log to Isar. Local ID: ${newLog.id}, Sync ID: ${newLog.syncId}');
    
    // Trigger sync in background
    syncPendingLogs();
  }

  // 2. Mark for deletion offline
  Future<void> deleteWorkLog(String syncId) async {
    final isar = await _isarService.db;
    
    final logToDelete = await isar.shopWorkLogIsars.filter().syncIdEqualTo(syncId).findFirst();
    if (logToDelete != null) {
      logToDelete.isDeleted = true;
      logToDelete.isSynced = false; // Mark for sync again to communicate deletion
      
      await isar.writeTxn(() async {
        await isar.shopWorkLogIsars.put(logToDelete);
      });
      
      log('Marked work log for deletion. Sync ID: $syncId');
      syncPendingLogs();
    }
  }

  // 3. Sync pending logs to POS API
  Future<void> syncPendingLogs() async {
    final isar = await _isarService.db;
    
    final pendingLogs = await isar.shopWorkLogIsars
        .filter()
        .isSyncedEqualTo(false)
        .findAll();

    if (pendingLogs.isEmpty) return;

    // Process creations/updates
    final toSync = pendingLogs.where((log) => !log.isDeleted).toList();
    if (toSync.isNotEmpty) {
      try {
        final payload = {
          'logs': toSync.map((log) => {
            'sync_id': log.syncId,
            'deliverer_id': log.delivererId,
            'logged_at': log.loggedAt?.toIso8601String(),
            'items': log.items?.map((item) => {
              'description': item.description,
              'quantity': item.quantity,
              'unit': item.unit,
            }).toList(),
          }).toList(),
        };

        final response = await _apiService.postRaw('/hr/worklogs/sync', payload);
        if (response != null && response['status'] == 'success') {
          // Mark as synced
          await isar.writeTxn(() async {
            for (var logEntry in toSync) {
              logEntry.isSynced = true;
              await isar.shopWorkLogIsars.put(logEntry);
            }
          });
          log('Successfully synced ${toSync.length} work logs to POS API.');
        }
      } catch (e) {
        log('Error syncing work logs to API: $e');
      }
    }

    // Process deletions
    final toDelete = pendingLogs.where((log) => log.isDeleted).toList();
    for (var delLog in toDelete) {
      if (delLog.syncId != null) {
        try {
          final response = await _apiService.deleteRaw('/hr/worklogs/${delLog.syncId}');
          if (response != null && response['status'] == 'success') {
            // Remove completely from Isar once deleted on server
            await isar.writeTxn(() async {
              await isar.shopWorkLogIsars.delete(delLog.id);
            });
            log('Successfully synced deletion for ${delLog.syncId}');
          }
        } catch (e) {
           log('Error syncing deletion for ${delLog.syncId}: $e');
        }
      }
    }
  }

  // 3.5 Sync Down (Fetch latest from server)
  Future<void> syncDownWorkLogs() async {
    try {
      final isar = await _isarService.db;
      final response = await _apiService.getRaw('/hr/worklogs');
      if (response != null && response['logs'] != null) {
        final List<dynamic> logs = response['logs'];
        
        await isar.writeTxn(() async {
          for (var logData in logs) {
            final syncId = logData['sync_id'];
            final delivererId = logData['deliverer_id'];
            final loggedAt = DateTime.tryParse(logData['logged_at'] ?? '');
            
            final existing = await isar.shopWorkLogIsars.filter().syncIdEqualTo(syncId).findFirst();
            if (existing == null) {
              final newLog = ShopWorkLogIsar()
                ..syncId = syncId
                ..delivererId = delivererId
                ..loggedAt = loggedAt ?? DateTime.now()
                ..isSynced = true
                ..isDeleted = false
                ..items = (logData['items'] as List<dynamic>?)?.map((item) => WorkItemIsar()
                  ..description = item['description']
                  ..quantity = (item['quantity'] as num?)?.toDouble() ?? 1.0
                  ..unit = item['unit']).toList();
              
              await isar.shopWorkLogIsars.put(newLog);
            }
          }
        });
        log('Successfully synced down ${logs.length} work logs.');
      }
    } catch (e) {
      log('Error syncing down work logs: $e');
    }
  }

  // 4. Get logs for UI (Stream)
  Stream<List<ShopWorkLogIsar>> watchWorkLogs() async* {
    final isar = await _isarService.db;
    yield* isar.shopWorkLogIsars
        .filter()
        .isDeletedEqualTo(false)
        .sortByLoggedAtDesc()
        .watch(fireImmediately: true);
  }
}
