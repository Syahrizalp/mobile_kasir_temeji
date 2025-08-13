// lib/src/repositories/user_dao.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../services/db.dart';

/// Data Access Object untuk tabel `users` + `log_aktivitas`.
class UserDao {
  final _db = AppDatabase();

  // ------------------------------------------------------------
  // util
  // ------------------------------------------------------------
  String _sha256(String s) => sha256.convert(utf8.encode(s)).toString();

  /// Validasi level agar sesuai CHECK constraint DB.
  void _ensureValidLevel(String level) {
    const allowed = {'admin', 'kasir', 'finance', 'owner'};
    if (!allowed.contains(level)) {
      throw ArgumentError(
          "Level tidak valid: '$level' (harus salah satu dari $allowed)");
    }
  }

  // ------------------------------------------------------------
  // query dasar
  // ------------------------------------------------------------
  Future<Map<String, dynamic>?> findByUsername(String username) async {
    final db = await _db.database;
    final rows = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> findById(int idUsers) async {
    final db = await _db.database;
    final rows = await db.query(
      'users',
      where: 'id_users = ?',
      whereArgs: [idUsers],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<bool> usernameExists(String username) async {
    final db = await _db.database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM users WHERE username = ?',
          [username],
        )) ??
        0;
    return count > 0;
  }

  // ------------------------------------------------------------
  // autentikasi
  // ------------------------------------------------------------
  /// Login: hash password input (SHA-256) dan bandingkan dengan kolom `password` (hex lower-case).
  Future<bool> login(String username, String password) async {
    final row = await findByUsername(username);
    if (row == null) return false;
    final hashed = _sha256(password);
    final ok = (row['password'] as String) == hashed;

    // tulis log
    try {
      await logActivity(
          row['id_users'] as int? ?? 0,
          ok
              ? 'Login berhasil untuk $username'
              : 'Login gagal untuk $username (password salah)');
    } catch (_) {
      // diamkan saja kalau log gagal
    }

    return ok;
  }

  Future<String?> levelOf(String username) async {
    final row = await findByUsername(username);
    return row?['level'] as String?;
  }

  // ------------------------------------------------------------
  // CRUD user
  // ------------------------------------------------------------
  /// Register user baru. Password otomatis di-hash (SHA-256).
  Future<int> register({
    required String username,
    required String password,
    required String level,
    required String namaAsli,
  }) async {
    _ensureValidLevel(level);
    final db = await _db.database;

    // hindari duplikat username
    if (await usernameExists(username)) {
      throw StateError('Username sudah dipakai');
    }

    final id = await db.insert('users', {
      'username': username.trim(),
      'password': _sha256(password),
      'level': level,
      'nama_asli': namaAsli.trim(),
    });

    await logActivity(id, 'Register user $username ($level)');
    return id;
  }

  /// Ubah password user (langsung set password baru).
  Future<int> changePassword({
    required int idUsers,
    required String newPassword,
  }) async {
    final db = await _db.database;
    final affected = await db.update(
      'users',
      {'password': _sha256(newPassword)},
      where: 'id_users = ?',
      whereArgs: [idUsers],
    );
    if (affected > 0) {
      await logActivity(idUsers, 'Ubah password');
    }
    return affected;
  }

  /// Ubah password dengan verifikasi password lama.
  Future<int> changePasswordWithOld({
    required int idUsers,
    required String oldPassword,
    required String newPassword,
  }) async {
    final row = await findById(idUsers);
    if (row == null) throw StateError('User tidak ditemukan');
    final oldHash = _sha256(oldPassword);
    if (row['password'] != oldHash) {
      throw StateError('Password lama tidak cocok');
    }
    return changePassword(idUsers: idUsers, newPassword: newPassword);
  }

  /// Update profil dasar (username, level, nama_asli).
  Future<int> updateProfile({
    required int idUsers,
    String? username,
    String? level,
    String? namaAsli,
  }) async {
    final db = await _db.database;
    final data = <String, Object?>{};
    if (username != null) data['username'] = username.trim();
    if (level != null) {
      _ensureValidLevel(level);
      data['level'] = level;
    }
    if (namaAsli != null) data['nama_asli'] = namaAsli.trim();
    if (data.isEmpty) return 0;

    final affected = await db.update(
      'users',
      data,
      where: 'id_users = ?',
      whereArgs: [idUsers],
      conflictAlgorithm: ConflictAlgorithm.abort, // cegah username ganda
    );
    if (affected > 0) {
      await logActivity(idUsers, 'Update profil user');
    }
    return affected;
  }

  /// Hapus user.
  Future<int> deleteUser(int idUsers) async {
    final db = await _db.database;
    final affected =
        await db.delete('users', where: 'id_users = ?', whereArgs: [idUsers]);
    if (affected > 0) {
      // catatan: saat user sudah terhapus, kita tidak bisa tulis log dgn FK.
      // jika ingin jejak, tulis log sebelum delete, misalnya ambil username dulu.
    }
    return affected;
  }

  /// Ambil daftar user (opsional filter: keyword, level).
  Future<List<Map<String, dynamic>>> getAll({
    String? keyword,
    String? level,
    String orderBy = 'username ASC',
  }) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object?>[];

    if (keyword != null && keyword.trim().isNotEmpty) {
      where.add('(username LIKE ? OR nama_asli LIKE ?)');
      final k = '%${keyword.trim()}%';
      args..add(k)..add(k);
    }
    if (level != null && level.trim().isNotEmpty) {
      _ensureValidLevel(level);
      where.add('level = ?');
      args.add(level);
    }

    return db.query(
      'users',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: orderBy,
    );
  }

  // ------------------------------------------------------------
  // log aktivitas
  // ------------------------------------------------------------
  Future<void> logActivity(int idUsers, String keterangan) async {
    final db = await _db.database;
    await db.insert('log_aktivitas', {
      'id_users': idUsers,
      'keterangan': keterangan,
      // 'tanggal' auto CURRENT_TIMESTAMP
    });
  }
}
