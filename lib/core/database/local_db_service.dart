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
      version: 1,
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
        orderId         INTEGER NOT NULL UNIQUE,
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
        lastUpdatedAt   TEXT
      )
    ''');

    // ── ตาราง 2: คิวส่งรูปออฟไลน์ ──
    await db.execute('''
      CREATE TABLE sync_queue (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        jobId           TEXT NOT NULL,
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

    log('$_tag All tables created successfully');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    log('$_tag Upgrading DB from v$oldVersion to v$newVersion');
  }

  // ═══════════════════════════════════════════════════
  // LOCAL JOBS CRUD
  // ═══════════════════════════════════════════════════

  Future<void> upsertJob(Map<String, dynamic> apiJob) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final orderId = apiJob['orderId'];
    final customer = apiJob['customer'] as Map<String, dynamic>? ?? {};
    final items = apiJob['items'] as List<dynamic>? ?? [];

    final row = {
      'orderId':         orderId,
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
    };

    await db.insert('local_jobs', row, conflictAlgorithm: ConflictAlgorithm.replace);
    log('$_tag Upsert job orderId=$orderId');
  }

  Future<List<Map<String, dynamic>>> getActiveJobs() async {
    final db = await database;
    final rows = await db.query(
      'local_jobs',
      where: "status != 'completed' AND proofImagePath IS NULL",
      orderBy: 'createdAt DESC',
    );
    log('$_tag Loaded ${rows.length} active jobs from local DB');
    return rows;
  }

  Future<List<Map<String, dynamic>>> getAllJobs() async {
    final db = await database;
    return await db.query('local_jobs', orderBy: 'createdAt DESC');
  }

  Future<Map<String, dynamic>?> getJobByOrderId(int orderId) async {
    final db = await database;
    final rows = await db.query(
      'local_jobs',
      where: 'orderId = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<void> markJobCompleted({
    required int orderId,
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
      where: 'orderId = ?',
      whereArgs: [orderId],
    );
    log('$_tag Marked job orderId=$orderId as completed ($count rows)');
  }

  Future<void> deleteJob(int orderId) async {
    final db = await database;
    final count = await db.delete('local_jobs', where: 'orderId = ?', whereArgs: [orderId]);
    log('$_tag Deleted job orderId=$orderId ($count rows)');
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

  Future<int> enqueueSync(Map<String, dynamic> data) async {
    final db = await database;
    final id = await db.insert('sync_queue', {
      'jobId':             data['jobId']?.toString() ?? '',
      'orderId':           data['orderId'],
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

  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: "syncStatus = 'pending'",
      orderBy: 'createdAt ASC',
    );
  }

  Future<void> updateSyncStatus(int id, String status) async {
    final db = await database;
    final current = await _getRetryCount(id);
    await db.update(
      'sync_queue',
      {
        'syncStatus':  status,
        'lastRetryAt': DateTime.now().toIso8601String(),
        'retryCount':  current + 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    log('$_tag sync_queue id=$id -> status=$status (retry #${current + 1})');
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
