import 'package:sqflite/sqflite.dart';
import '../models/menu.dart';
import '../services/db.dart';

class MenuDao {
  Future<Database> get _db async => AppDatabase().database;

  Future<int> insert(MenuItem item) async {
    final db = await _db;
    return db.insert('menu', item.toMap());
  }

  Future<int> update(MenuItem item) async {
    final db = await _db;
    return db.update(
      'menu',
      item.toMap(),
      where: 'id_menu = ?',
      whereArgs: [item.idMenu],
    );
  }

  Future<int> delete(int idMenu) async {
    final db = await _db;
    return db.delete('menu', where: 'id_menu = ?', whereArgs: [idMenu]);
  }

  Future<List<MenuItem>> getAll({String? keyword}) async {
    final db = await _db;
    List<Map<String, Object?>> rows;
    if (keyword != null && keyword.trim().isNotEmpty) {
      rows = await db.query(
        'menu',
        where: 'nama_menu LIKE ?',
        whereArgs: ['%$keyword%'],
        orderBy: 'nama_menu ASC',
      );
    } else {
      rows = await db.query('menu', orderBy: 'nama_menu ASC');
    }
    return rows.map((e) => MenuItem.fromMap(e)).toList();
  }

  Future<MenuItem?> getById(int idMenu) async {
    final db = await _db;
    final rows = await db.query(
      'menu',
      where: 'id_menu = ?',
      whereArgs: [idMenu],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MenuItem.fromMap(rows.first);
  }
}
