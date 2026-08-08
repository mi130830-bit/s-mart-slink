// ไฟล์: lib/core/database/local_db_service.dart
// [Milestone 2] ฐานข้อมูล SQLite ในมือถือสำหรับ Cache งานจัดส่งแบบ Offline

import 'dart:convert';
import 'dart:developer';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  static Database? _db;
  static const String _tag = '[LocalDB]';

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'slink_offline.db');
    log('$_tag Initializing database at: $path');
    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    log('$_tag Creating tables (version $version)...');

    // ── ตาราง 1: งานจัดส่ง (Local Cache) ──
    await db.execute('''
      CREATE TABLE local_jobs (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId         INTEGER NOT NULL,
        ownerUid        TEXT NOT NULL DEFAULT '',
        firebaseJobId   TEXT,
        status          TEXT NOT NULL DEFAULT 'pending',
        jobType         TEXT NOT NULL DEFAULT 'delivery',
        paymentMethod   TEXT NOT NULL DEFAULT 'cash',
        totalAmount     REAL NOT NULL DEFAULT 0,
        note            TEXT,
        createdAt       TEXT,
        customerName    TEXT,
        customerPhone   TEXT,
        customerAddress TEXT,
        customerLat     REAL,
        customerLng     REAL,
        itemsJson       TEXT DEFAULT '[]',
        proofImagePath  TEXT,
        proofLat        REAL,
        proofLng        REAL,
        completedAt     TEXT,
        downloadedAt    TEXT NOT NULL,
        lastUpdatedAt   TEXT,
        isDepartureApproved INTEGER DEFAULT 0,
        driverIds       TEXT DEFAULT '[]',
        vehicleIds      TEXT DEFAULT '[]',
        deliveryTeamJson TEXT DEFAULT '[]',
        UNIQUE(ownerUid, orderId)
      )
    ''');

    // ── ตาราง 2: คิวส่งรูปออฟไลน์ ──
    await db.execute('''
      CREATE TABLE sync_queue (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        jobId           TEXT NOT NULL,
        ownerUid        TEXT NOT NULL DEFAULT '',
        orderId         INTEGER,
        firebaseJobId   TEXT,
        driverUid       TEXT,
        driverName      TEXT,
        vehiclePlate    TEXT,
        customerName    TEXT,
        customerPhone   TEXT,
        customerAddress TEXT,
        totalAmount     REAL,
        jobType         TEXT,
        proofImagePath  TEXT,
        proofLat        REAL,
        proofLng        REAL,
        collectedCod    REAL,
        deliveryTeamJson TEXT DEFAULT '[]',
        createdAt       TEXT NOT NULL,
        retryCount      INTEGER NOT NULL DEFAULT 0,
        lastRetryAt     TEXT,
        syncStatus      TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_local_jobs_owner_status ON local_jobs(ownerUid, status)');
    await db.execute(
        'CREATE INDEX idx_sync_queue_status_created_at ON sync_queue(syncStatus, createdAt)');
    await db.execute(
        'CREATE INDEX idx_sync_queue_owner_status ON sync_queue(ownerUid, syncStatus)');

    log('$_tag All tables created successfully');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    log('$_tag Upgrading DB from v$oldVersion to v$newVersion');
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE local_jobs ADD COLUMN isDepartureApproved INTEGER DEFAULT 0');
      await db.execute("ALTER TABLE local_jobs ADD COLUMN driverIds TEXT DEFAULT '[]'");
      await db.execute("ALTER TABLE local_jobs ADD COLUMN vehicleIds TEXT DEFAULT '[]'");
      await db.execute("ALTER TABLE local_jobs ADD COLUMN deliveryTeamJson TEXT DEFAULT '[]'");
    }
    if (oldVersion < 3) {
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_queue_status_created_at ON sync_queue(syncStatus, createdAt)');
    }
    if (oldVersion < 4) {
      await db.execute(
          "ALTER TABLE local_jobs ADD COLUMN ownerUid TEXT NOT NULL DEFAULT ''");
      await db.execute(
          "ALTER TABLE sync_queue ADD COLUMN ownerUid TEXT NOT NULL DEFAULT ''");
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_local_jobs_owner_status ON local_jobs(ownerUid, status)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_sync_queue_owner_status ON sync_queue(ownerUid, syncStatus)');
    }
    if (oldVersion < 5) {
      // Version 4 scoped rows by user but retained the old global UNIQUE
      // constraint on orderId. Rebuild so multiple accounts on one device
      // cannot overwrite each other's cache.
      await db.execute('''
        CREATE TABLE local_jobs_v5 (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          orderId INTEGER NOT NULL,
          ownerUid TEXT NOT NULL DEFAULT '',
          firebaseJobId TEXT, status TEXT NOT NULL DEFAULT 'pending',
          jobType TEXT NOT NULL DEFAULT 'delivery', paymentMethod TEXT NOT NULL DEFAULT 'cash',
          totalAmount REAL NOT NULL DEFAULT 0, note TEXT, createdAt TEXT,
          customerName TEXT, customerPhone TEXT, customerAddress TEXT,
          customerLat REAL, customerLng REAL, itemsJson TEXT DEFAULT '[]',
          proofImagePath TEXT, proofLat REAL, proofLng REAL, completedAt TEXT,
          downloadedAt TEXT NOT NULL, lastUpdatedAt TEXT,
          isDepartureApproved INTEGER DEFAULT 0, driverIds TEXT DEFAULT '[]',
          vehicleIds TEXT DEFAULT '[]', deliveryTeamJson TEXT DEFAULT '[]',
          UNIQUE(ownerUid, orderId)
        )
      ''');
      await db.execute('''
        INSERT INTO local_jobs_v5 (
          id, orderId, ownerUid, firebaseJobId, status, jobType, paymentMethod,
          totalAmount, note, createdAt, customerName, customerPhone,
          customerAddress, customerLat, customerLng, itemsJson, proofImagePath,
          proofLat, proofLng, completedAt, downloadedAt, lastUpdatedAt,
          isDepartureApproved, driverIds, vehicleIds, deliveryTeamJson
        ) SELECT
          id, orderId, ownerUid, firebaseJobId, status, jobType, paymentMethod,
          totalAmount, note, createdAt, customerName, customerPhone,
          customerAddress, customerLat, customerLng, itemsJson, proofImagePath,
          proofLat, proofLng, completedAt, downloadedAt, lastUpdatedAt,
          isDepartureApproved, driverIds, vehicleIds, deliveryTeamJson
        FROM local_jobs
      ''');
      await db.execute('DROP TABLE local_jobs');
      await db.execute('ALTER TABLE local_jobs_v5 RENAME TO local_jobs');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_local_jobs_owner_status ON local_jobs(ownerUid, status)');
    }
  }

  // ═══════════════════════════════════════════════════
  // LOCAL JOBS CRUD
  // ═══════════════════════════════════════════════════

  Future<void> upsertJob(
    Map<String, dynamic> apiJob, {
    required String ownerUid,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final orderId = apiJob['orderId'];
    final customer = apiJob['customer'] as Map<String, dynamic>? ?? {};
    final items = apiJob['items'] as List<dynamic>? ?? [];

    final row = {
      'orderId':         orderId,
      'ownerUid':        ownerUid,
      'firebaseJobId':   apiJob['firebaseJobId'] ?? '',
      'status':          apiJob['status'] ?? 'pending',
      'jobType':         apiJob['jobType'] ?? 'delivery',
      'paymentMethod':   apiJob['paymentMethod'] ?? 'cash',
      'totalAmount':     double.tryParse(apiJob['totalAmount']?.toString() ?? '0') ?? 0.0,
      'note':            apiJob['note'] ?? '',
      'createdAt':       apiJob['createdAt'] ?? now,
      'customerName':    customer['name'] ?? '',
      'customerPhone':   customer['phone'] ?? '',
      'customerAddress': customer['address'] ?? '',
      'customerLat':     double.tryParse(customer['lat']?.toString() ?? '') ?? 0.0,
      'customerLng':     double.tryParse(customer['lng']?.toString() ?? '') ?? 0.0,
      'itemsJson':       jsonEncode(items),
      'downloadedAt':    now,
      'lastUpdatedAt':   now,
      'isDepartureApproved':
          apiJob['isDepartureApproved'] == true ||
                  apiJob['is_departure_approved'] == true
              ? 1
              : 0,
      'driverIds': jsonEncode(apiJob['driverIds'] ?? apiJob['driver_ids'] ?? []),
      'vehicleIds': jsonEncode(apiJob['vehicleIds'] ?? apiJob['vehicle_ids'] ?? []),
      'deliveryTeamJson':
          jsonEncode(apiJob['deliveryTeam'] ?? apiJob['delivery_team'] ?? []),
    };

    // Prevent Overwriting Offline Completed Jobs (Zombie Job Fix)
    final existing = await db.query(
      'local_jobs',
      columns: ['status', 'proofImagePath', 'isDepartureApproved', 'driverIds', 'vehicleIds', 'deliveryTeamJson'],
      where: 'orderId = ? AND ownerUid = ?',
      whereArgs: [orderId, ownerUid],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final local = existing.first;
      if (local['status'] == 'completed' || local['proofImagePath'] != null) {
        log('$_tag Job $orderId is completed locally. Skipping overwrite from API.');
        return;
      }
      
      // Preserve locally assigned data only when the API response does not
      // contain it. This prevents a stale local cache from overwriting the
      // latest driver assignment or departure approval from the server.
      if ((apiJob['driverIds'] ?? apiJob['driver_ids']) == null) {
        row['driverIds'] = local['driverIds'] ?? '[]';
      }
      if ((apiJob['vehicleIds'] ?? apiJob['vehicle_ids']) == null) {
        row['vehicleIds'] = local['vehicleIds'] ?? '[]';
      }
      if ((apiJob['deliveryTeam'] ?? apiJob['delivery_team']) == null) {
        row['deliveryTeamJson'] = local['deliveryTeamJson'] ?? '[]';
      }
      if (apiJob['isDepartureApproved'] == null &&
          apiJob['is_departure_approved'] == null) {
        row['isDepartureApproved'] = local['isDepartureApproved'] ?? 0;
      }
    }

    await db.insert('local_jobs', row, conflictAlgorithm: ConflictAlgorithm.replace);
    log('$_tag Upsert job orderId=$orderId');
  }

  Future<List<Map<String, dynamic>>> getActiveJobs(String ownerUid) async {
    final db = await database;
    final rows = await db.query(
      'local_jobs',
      where: "ownerUid = ? AND status != 'completed' AND proofImagePath IS NULL",
      whereArgs: [ownerUid],
      orderBy: 'createdAt DESC',
    );
    log('$_tag Loaded ${rows.length} active jobs from local DB');
    return rows;
  }

  Future<void> updateOfflineAssignment(
    int orderId,
    bool isDepartureApproved,
    List<String> driverIds,
    List<String> vehicleIds,
    List<dynamic> deliveryTeam,
    String ownerUid,
  ) async {
    final db = await database;
    await db.update(
      'local_jobs',
      {
        'isDepartureApproved': isDepartureApproved ? 1 : 0,
        'driverIds': jsonEncode(driverIds),
        'vehicleIds': jsonEncode(vehicleIds),
        'deliveryTeamJson': jsonEncode(deliveryTeam),
      },
      where: 'orderId = ? AND ownerUid = ?',
      whereArgs: [orderId, ownerUid],
    );
    log('$_tag Updated offline assignment for orderId=$orderId');
  }

  Future<List<Map<String, dynamic>>> getAllJobs() async {
    final db = await database;
    return await db.query('local_jobs', orderBy: 'createdAt DESC');
  }

  Future<Map<String, dynamic>?> getJobByOrderId(
      int orderId, String ownerUid) async {
    final db = await database;
    final rows = await db.query(
      'local_jobs',
      where: 'orderId = ? AND ownerUid = ?',
      whereArgs: [orderId, ownerUid],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<void> markJobCompleted({
    required int orderId,
    required String ownerUid,
    required String proofImagePath,
    required double proofLat,
    required double proofLng,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final count = await db.update(
      'local_jobs',
      {
        'status':         'completed',
        'proofImagePath': proofImagePath,
        'proofLat':       proofLat,
        'proofLng':       proofLng,
        'completedAt':    now,
        'lastUpdatedAt':  now,
      },
      where: 'orderId = ? AND ownerUid = ?',
      whereArgs: [orderId, ownerUid],
    );
    log('$_tag Marked job orderId=$orderId as completed ($count rows)');
  }

  Future<void> deleteJob(int orderId, String ownerUid) async {
    final db = await database;
    final count = await db.delete(
      'local_jobs',
      where: 'orderId = ? AND ownerUid = ?',
      whereArgs: [orderId, ownerUid],
    );
    log('$_tag Deleted job orderId=$orderId ($count rows)');
  }

  /// Version 4 adds user scopes. Records created by older app versions had no
  /// owner, so claim them once for the first authenticated user after upgrade.
  Future<void> claimUnownedRecords(String ownerUid) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'local_jobs',
        {'ownerUid': ownerUid},
        where: "ownerUid = ''",
      );
      await txn.update(
        'sync_queue',
        {'ownerUid': ownerUid},
        where: "ownerUid = ''",
      );
    });
  }

  Future<int> cleanupOldCompletedJobs() async {
    final db = await database;
    final cutoff = DateTime.now().subtract(const Duration(days: 3)).toIso8601String();
    final count = await db.delete(
      'local_jobs',
      where: "status = 'completed' AND completedAt < ?",
      whereArgs: [cutoff],
    );
    if (count > 0) log('$_tag Auto-cleanup: removed $count completed jobs older than 3 days');
    return count;
  }

  // ═══════════════════════════════════════════════════
  // SYNC QUEUE
  // ═══════════════════════════════════════════════════

  Future<int> enqueueSync(Map<String, dynamic> data, String ownerUid) async {
    final db = await database;
    return _enqueueSync(db, data, ownerUid);
  }

  Future<int> _enqueueSync(
    DatabaseExecutor executor,
    Map<String, dynamic> data,
    String ownerUid,
  ) async {
    final jobId = data['jobId']?.toString() ?? '';
    final orderId = data['orderId'];

    // A double tap or reconnect must not create two completion requests for
    // the same job, especially because it can duplicate a COD payment.
    final existing = await executor.query(
      'sync_queue',
      columns: ['id'],
      where: 'ownerUid = ? AND jobId = ? AND syncStatus IN (?, ?)',
      whereArgs: [ownerUid, jobId, 'pending', 'uploading'],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    }

    final id = await executor.insert('sync_queue', {
      'jobId':             jobId,
      'ownerUid':          ownerUid,
      'orderId':           orderId,
      'firebaseJobId':     data['firebaseJobId'] ?? '',
      'driverUid':         data['driverUid'] ?? '',
      'driverName':        data['driverName'] ?? '',
      'vehiclePlate':      data['vehiclePlate'] ?? '',
      'customerName':      data['customerName'] ?? '',
      'customerPhone':     data['customerPhone'] ?? '',
      'customerAddress':   data['customerAddress'] ?? '',
      'totalAmount':       data['totalAmount'] ?? 0.0,
      'jobType':           data['jobType'] ?? 'delivery',
      'proofImagePath':    data['localImagePath'] ?? '',
      'proofLat':          data['lat'] ?? 0.0,
      'proofLng':          data['lng'] ?? 0.0,
      'collectedCod':      data['collectedCod'],
      'deliveryTeamJson':  jsonEncode(data['deliveryTeam'] ?? []),
      'createdAt':         DateTime.now().toIso8601String(),
      'syncStatus':        'pending',
    });
    log('$_tag Enqueued offline job to sync_queue (id=$id, jobId=${data['jobId']})');
    return id;
  }

  /// Queue the completion and hide the job locally in the same transaction.
  /// A crash can no longer leave one action saved without the other.
  Future<void> queueCompletedJob(
    Map<String, dynamic> data,
    String ownerUid,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await _enqueueSync(txn, data, ownerUid);
      final orderId = int.tryParse(data['orderId']?.toString() ?? '');
      if (orderId == null) return;
      await txn.update(
        'local_jobs',
        {
          'status': 'completed',
          'proofImagePath': data['localImagePath'] ?? '',
          'proofLat': (data['lat'] as num?)?.toDouble() ?? 0.0,
          'proofLng': (data['lng'] as num?)?.toDouble() ?? 0.0,
          'completedAt': DateTime.now().toIso8601String(),
          'lastUpdatedAt': DateTime.now().toIso8601String(),
        },
        where: 'orderId = ? AND ownerUid = ?',
        whereArgs: [orderId, ownerUid],
      );
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncItems(String ownerUid) async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: "ownerUid = ? AND syncStatus = 'pending'",
      whereArgs: [ownerUid],
      orderBy: 'createdAt ASC',
    );
  }

  Future<void> updateSyncStatus(int id, String status) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {
        'syncStatus':  status,
        'lastRetryAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    log('$_tag sync_queue id=$id -> status=$status');
  }

  Future<void> recordSyncFailure(int id) async {
    final db = await database;
    final current = await _getRetryCount(id);
    await db.update(
      'sync_queue',
      {
        'syncStatus': 'pending',
        'lastRetryAt': DateTime.now().toIso8601String(),
        'retryCount': current + 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    log('$_tag sync_queue id=$id failed (retry #${current + 1})');
  }

  Future<void> recoverInterruptedSyncs(String ownerUid) async {
    final db = await database;
    final count = await db.update(
      'sync_queue',
      {'syncStatus': 'pending'},
      where: 'ownerUid = ? AND syncStatus = ?',
      whereArgs: [ownerUid, 'uploading'],
    );
    if (count > 0) log('$_tag Recovered $count interrupted sync item(s)');
  }

  Future<int> _getRetryCount(int id) async {
    final db = await database;
    final rows = await db.query('sync_queue', columns: ['retryCount'], where: 'id = ?', whereArgs: [id]);
    return int.tryParse(rows.firstOrNull?['retryCount']?.toString() ?? '0') ?? 0;
  }

  Future<void> removeSyncItem(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
    log('$_tag Removed sync_queue item id=$id (sync complete)');
  }

  // ═══════════════════════════════════════════════════
  // DIAGNOSTICS
  // ═══════════════════════════════════════════════════

  Future<Map<String, int>> getDiagnostics() async {
    final db = await database;
    final activeCount = (await db.query('local_jobs', where: "status != 'completed'")).length;
    final pendingSync = (await db.query('sync_queue', where: "syncStatus = 'pending'")).length;
    final failedSync  = (await db.query('sync_queue', where: "syncStatus = 'failed'")).length;
    log('$_tag Diagnostics: activeJobs=$activeCount, pendingSync=$pendingSync, failedSync=$failedSync');
    return {'activeJobs': activeCount, 'pendingSync': pendingSync, 'failedSync': failedSync};
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('local_jobs');
    await db.delete('sync_queue');
    log('$_tag WARNING: All local data cleared!');
  }
}
