// lib/src/services/db.dart
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  static const _dbName = 'temeji.db';
  // Naikkan bila kamu ubah struktur/migrasi
  static const _dbVersion = 2;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    final path = join(dir, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onOpen: (db) async {
        // jaga-jaga aktifkan FK lagi & seed jika kosong
        await db.execute('PRAGMA foreign_keys = ON;');
        await _seedIfUsersEmpty(db);
      },
      onCreate: (db, v) async {
        await _createSchema(db);
        await _createIndexes(db);
        await _seedInitialUsers(db); // seed hanya di sini
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await _migrateMenuGambarToPath(db);
        }
        await _seedIfUsersEmpty(db);
      },
    );
    return _db!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id_users  INTEGER PRIMARY KEY AUTOINCREMENT,
      username  TEXT NOT NULL UNIQUE,
      password  TEXT NOT NULL, -- SHA-256 hex
      level     TEXT NOT NULL CHECK(level IN ('admin','kasir','finance','owner')),
      nama_asli TEXT NOT NULL
    );
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS menu (
      id_menu     INTEGER PRIMARY KEY AUTOINCREMENT,
      nama_menu   TEXT NOT NULL,
      harga       NUMERIC NOT NULL,
      stok        INTEGER NOT NULL,
      kategori    TEXT NOT NULL,
      ukuran_menu TEXT NOT NULL,
      path_gambar TEXT NOT NULL
    );
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS transaksi (
      id_transaksi TEXT PRIMARY KEY,
      id_users     INTEGER NOT NULL,
      tanggal_transaksi TEXT DEFAULT (CURRENT_TIMESTAMP),
      total_harga       NUMERIC,
      uang_pembayaran   NUMERIC,
      uang_kembalian    NUMERIC,
      id_pembeli        TEXT NOT NULL,
      metode            TEXT,
      PersenPajak       REAL NOT NULL,
      pajak             NUMERIC NOT NULL,
      Total_setelah_Pajak NUMERIC NOT NULL,
      FOREIGN KEY (id_users) REFERENCES users(id_users)
        ON DELETE CASCADE ON UPDATE CASCADE
    );
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS detail_transaksi (
      id_detail    INTEGER PRIMARY KEY AUTOINCREMENT,
      id_transaksi TEXT,
      id_menu      INTEGER,
      kuantitas    INTEGER NOT NULL,
      subtotal     NUMERIC NOT NULL,
      FOREIGN KEY (id_transaksi) REFERENCES transaksi(id_transaksi)
        ON DELETE SET NULL ON UPDATE CASCADE,
      FOREIGN KEY (id_menu) REFERENCES menu(id_menu)
        ON DELETE SET NULL ON UPDATE CASCADE
    );
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS log_aktivitas (
      id_aktivitas INTEGER PRIMARY KEY AUTOINCREMENT,
      id_users     INTEGER NOT NULL,
      keterangan   TEXT NOT NULL,
      tanggal      TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP),
      FOREIGN KEY (id_users) REFERENCES users(id_users)
        ON DELETE CASCADE ON UPDATE CASCADE
    );
    ''');

    await db.execute('''
    CREATE TABLE IF NOT EXISTS wifi (
      id_wifi   INTEGER PRIMARY KEY AUTOINCREMENT,
      nama_wifi TEXT NOT NULL,
      pass_wifi TEXT NOT NULL
    );
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_detail_idtrans ON detail_transaksi(id_transaksi);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_detail_idmenu ON detail_transaksi(id_menu);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_transaksi_iduser ON transaksi(id_users);');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_log_iduser ON log_aktivitas(id_users);');
  }

  Future<void> _seedInitialUsers(Database db) async {
    final users = [
      {
        'id_users': 100,
        'username': 'admin',
        'password':
            '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918',
        'level': 'admin',
        'nama_asli': 'adminn'
      },
      {
        'id_users': 101,
        'username': 'kasir',
        'password':
            '2c7ee7ade401a7cef9ef4dad9978998cf42ed805243d6c91f89408c6097aa571',
        'level': 'kasir',
        'nama_asli': 'kasirr'
      },
      {
        'id_users': 102,
        'username': 'owner',
        'password':
            '4c1029697ee358715d3a14a2add817c4b01651440de808371f78165ac90dc581',
        'level': 'owner',
        'nama_asli': 'ownerr'
      },
      {
        'id_users': 103,
        'username': 'finance',
        'password':
            'eab762a03fd979a04cc4706e6536d382bc89d2d1356afcd054a16b2235ecd471',
        'level': 'finance',
        'nama_asli': 'financee'
      },
    ];
    for (final u in users) {
      await db.insert('users', u, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _seedIfUsersEmpty(Database db) async {
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM users'),
        ) ??
        0;
    if (count == 0) {
      await _seedInitialUsers(db);
    }
  }

  Future<void> _migrateMenuGambarToPath(Database db) async {
    final info = await db.rawQuery('PRAGMA table_info(menu);');
    final cols = info.map((e) => (e['name'] as String).toLowerCase()).toSet();
    if (cols.contains('path_gambar')) return;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS menu_new (
        id_menu     INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_menu   TEXT NOT NULL,
        harga       NUMERIC NOT NULL,
        stok        INTEGER NOT NULL,
        kategori    TEXT NOT NULL,
        ukuran_menu TEXT NOT NULL,
        path_gambar TEXT NOT NULL
      );
    ''');

    await db.execute('''
      INSERT INTO menu_new (id_menu, nama_menu, harga, stok, kategori, ukuran_menu, path_gambar)
      SELECT id_menu, nama_menu, harga, stok, kategori, ukuran_menu, ''
      FROM menu;
    ''');

    await db.execute('DROP TABLE menu;');
    await db.execute('ALTER TABLE menu_new RENAME TO menu;');
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('detail_transaksi');
      await txn.delete('transaksi');
      await txn.delete('menu');
      await txn.delete('log_aktivitas');
      await txn.delete('wifi');
      await txn.delete('users');
    });
  }

  Future<T> inTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction<T>(action);
  }
}
