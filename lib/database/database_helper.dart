import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/health_record.dart';

/// DATABASE LAYER – stores health records in a local SQLite database
/// using the `sqflite` package.
///
/// * One shared connection for the whole app ([DatabaseHelper.instance]).
/// * Tables are created the first time the app runs ([_onCreate]) and
///   filled with a few dummy records for testing.
/// * Every query uses `?` placeholders (parameterised queries), which
///   protects against SQL injection.
/// * Records are converted with `HealthRecord.toMap()` / `fromMap()`.
///
/// Tables:
/// ```sql
/// CREATE TABLE health_records (
///   id       INTEGER PRIMARY KEY AUTOINCREMENT,
///   date     TEXT    NOT NULL,   -- "yyyy-MM-dd"
///   steps    INTEGER NOT NULL,
///   calories INTEGER NOT NULL,
///   water    INTEGER NOT NULL    -- millilitres
/// );
/// CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
/// ```
class DatabaseHelper {
  DatabaseHelper._internal({
    DatabaseFactory? factory,
    String? path,
    this.seedSampleData = true,
  })  : _factory = factory,
        _path = path;

  /// Single shared instance used by the app (singleton pattern).
  static final DatabaseHelper instance = DatabaseHelper._internal();

  /// Separate in-memory database for tests (nothing is written to disk).
  factory DatabaseHelper.forTesting({
    required DatabaseFactory factory,
    bool seedSampleData = false,
  }) =>
      DatabaseHelper._internal(
        factory: factory,
        path: inMemoryDatabasePath,
        seedSampleData: seedSampleData,
      );

  static const String databaseName = 'healthmate.db';
  static const int databaseVersion = 1;

  static const String tableHealthRecords = 'health_records';
  static const String tableSettings = 'app_settings';

  static const String _keyStepsGoal = 'goal_steps';
  static const String _keyCaloriesGoal = 'goal_calories';
  static const String _keyWaterGoal = 'goal_water';
  static const String _keyThemeMode = 'theme_mode';

  /// Newest day first; within a day, the newest entry first.
  static const String _orderBy =
      '${HealthRecord.colDate} DESC, ${HealthRecord.colId} DESC';

  final DatabaseFactory? _factory;
  final String? _path;

  /// Insert dummy records when the database is first created.
  final bool seedSampleData;

  Future<Database>? _database;

  // =================================================================
  // Open / create
  // =================================================================

  /// Opens the database once and reuses the same connection. The Future is
  /// cached so two screens asking at the same time share one connection.
  Future<Database> get database => _database ??= _open();

  Future<Database> _open() async {
    final factory = _factory ?? databaseFactory;
    final path =
        _path ?? p.join(await factory.getDatabasesPath(), databaseName);
    final inMemory = path == inMemoryDatabasePath;

    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        // Each test gets its own fresh in-memory database.
        singleInstance: !inMemory,
      ),
    );
  }

  /// Runs only the first time the app is installed.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableHealthRecords (
        ${HealthRecord.colId}       INTEGER PRIMARY KEY AUTOINCREMENT,
        ${HealthRecord.colDate}     TEXT    NOT NULL,
        ${HealthRecord.colSteps}    INTEGER NOT NULL DEFAULT 0,
        ${HealthRecord.colCalories} INTEGER NOT NULL DEFAULT 0,
        ${HealthRecord.colWater}    INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Most queries filter or sort by date, so index that column.
    await db.execute(
      'CREATE INDEX idx_health_records_date '
      'ON $tableHealthRecords (${HealthRecord.colDate})',
    );

    await db.execute('''
      CREATE TABLE $tableSettings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Default preferences: standard goals and light mode.
    const goals = DailyGoals.defaults;
    final batch = db.batch();
    batch.insert(tableSettings, {'key': _keyStepsGoal, 'value': '${goals.steps}'});
    batch.insert(
      tableSettings,
      {'key': _keyCaloriesGoal, 'value': '${goals.calories}'},
    );
    batch.insert(tableSettings, {'key': _keyWaterGoal, 'value': '${goals.water}'});
    batch.insert(tableSettings, {'key': _keyThemeMode, 'value': 'light'});
    await batch.commit(noResult: true);

    if (seedSampleData) await _insertSampleData(db);
  }

  /// For future versions, e.g.
  /// `if (oldVersion < 2) await db.execute('ALTER TABLE ...');`
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}

  /// Closes the connection (used by tests).
  Future<void> close() async {
    final pending = _database;
    _database = null;
    if (pending != null) await (await pending).close();
  }

  // =================================================================
  // READ
  // =================================================================

  /// All records, newest first.
  Future<List<HealthRecord>> getAllRecords() async {
    final db = await database;
    final rows = await db.query(tableHealthRecords, orderBy: _orderBy);
    return rows.map(HealthRecord.fromMap).toList();
  }

  /// One record by id, or `null`.
  Future<HealthRecord?> getRecordById(int id) async {
    final db = await database;
    final rows = await db.query(
      tableHealthRecords,
      where: '${HealthRecord.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : HealthRecord.fromMap(rows.first);
  }

  /// Records for one day (search by date).
  Future<List<HealthRecord>> getRecordsByDate(DateTime date) async {
    final db = await database;
    final rows = await db.query(
      tableHealthRecords,
      where: '${HealthRecord.colDate} = ?',
      whereArgs: [DateUtil.toDbString(date)],
      orderBy: _orderBy,
    );
    return rows.map(HealthRecord.fromMap).toList();
  }

  /// Records between two dates, inclusive. Dates are stored as
  /// "yyyy-MM-dd" text, so BETWEEN compares them in the right order.
  Future<List<HealthRecord>> getRecordsInRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final rows = await db.query(
      tableHealthRecords,
      where: '${HealthRecord.colDate} BETWEEN ? AND ?',
      whereArgs: [DateUtil.toDbString(start), DateUtil.toDbString(end)],
      orderBy: _orderBy,
    );
    return rows.map(HealthRecord.fromMap).toList();
  }

  // =================================================================
  // CREATE
  // =================================================================

  /// Inserts a record and returns its new id. If the record already has an
  /// id (e.g. "Undo" after delete) the same id is reused.
  Future<int> insertRecord(HealthRecord record) async {
    final db = await database;
    return db.insert(
      tableHealthRecords,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // =================================================================
  // UPDATE
  // =================================================================

  /// Updates a record. Returns the number of rows changed.
  Future<int> updateRecord(HealthRecord record) async {
    if (record.id == null) {
      throw ArgumentError('Cannot update a record without an id');
    }
    final db = await database;
    return db.update(
      tableHealthRecords,
      record.toMap(),
      where: '${HealthRecord.colId} = ?',
      whereArgs: [record.id],
    );
  }

  // =================================================================
  // DELETE
  // =================================================================

  /// Deletes a record. Returns the number of rows removed.
  Future<int> deleteRecord(int id) async {
    final db = await database;
    return db.delete(
      tableHealthRecords,
      where: '${HealthRecord.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Deletes every record.
  Future<void> deleteAllRecords() async {
    final db = await database;
    await db.delete(tableHealthRecords);
  }

  /// Replaces all records with fresh dummy data (one transaction, so it
  /// either fully succeeds or nothing changes).
  Future<void> resetToSampleData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableHealthRecords);
      await _insertSampleData(txn);
    });
  }

  // =================================================================
  // Preferences (app_settings table)
  // =================================================================

  Future<Map<String, String>> _readSettings() async {
    final db = await database;
    final rows = await db.query(tableSettings);
    return {for (final row in rows) row['key'] as String: row['value'] as String};
  }

  Future<void> _writeSettings(Map<String, String> values) async {
    final db = await database;
    final batch = db.batch();
    values.forEach((key, value) {
      batch.insert(
        tableSettings,
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await batch.commit(noResult: true);
  }

  Future<DailyGoals> getGoals() async {
    final values = await _readSettings();
    int read(String key, int fallback) =>
        int.tryParse(values[key] ?? '') ?? fallback;
    const d = DailyGoals.defaults;
    return DailyGoals(
      steps: read(_keyStepsGoal, d.steps),
      calories: read(_keyCaloriesGoal, d.calories),
      water: read(_keyWaterGoal, d.water),
    );
  }

  Future<void> saveGoals(DailyGoals goals) => _writeSettings({
        _keyStepsGoal: '${goals.steps}',
        _keyCaloriesGoal: '${goals.calories}',
        _keyWaterGoal: '${goals.water}',
      });

  /// One of `light`, `dark` or `system`.
  Future<String> getThemeMode() async =>
      (await _readSettings())[_keyThemeMode] ?? 'light';

  Future<void> saveThemeMode(String value) =>
      _writeSettings({_keyThemeMode: value});

  // =================================================================
  // Dummy data
  // =================================================================

  Future<void> _insertSampleData(DatabaseExecutor db) async {
    final batch = db.batch();
    for (final record in generateSampleData()) {
      batch.insert(tableHealthRecords, record.toMap());
    }
    await batch.commit(noResult: true);
  }

  /// Seven dummy records (today + the previous 6 days) for initial
  /// testing, as required by the brief. Dates are relative to "today" so
  /// the dashboard and weekly chart have content on first launch.
  static List<HealthRecord> generateSampleData({DateTime? today}) {
    final now = DateUtil.dateOnly(today ?? DateTime.now());
    final random = Random(2026);
    final records = <HealthRecord>[
      // Today – partly completed so the progress rings are visible.
      HealthRecord(date: now, steps: 4250, calories: 210, water: 1250),
    ];
    for (var i = 1; i <= 6; i++) {
      final day = DateTime(now.year, now.month, now.day - i);
      final steps = 4000 + random.nextInt(8000);
      records.add(
        HealthRecord(
          date: day,
          steps: steps,
          calories: (steps * 0.05).round() + random.nextInt(60),
          water: 1500 + random.nextInt(5) * 250,
        ),
      );
    }
    return records;
  }
}
