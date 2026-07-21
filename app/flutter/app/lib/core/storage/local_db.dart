import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Local SQLite database for offline queue and cached reference data.
class LocalDb {
  static Database? _db;
  static const String _dbName = 'texerp.db';
  static const int _dbVersion = 1;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE offline_queue (
        local_id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'PENDING',
        error_msg TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0,
        server_id TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_offline_queue_status_created
      ON offline_queue (sync_status, created_at)
    ''');

    await db.execute('''
      CREATE TABLE cached_operations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT,
        unit TEXT NOT NULL,
        unit_price INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        cached_at TEXT NOT NULL
      )
    ''');
  }
}
