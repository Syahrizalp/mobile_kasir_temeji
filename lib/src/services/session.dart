import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static const _kId = 'id_users';
  static const _kUsername = 'username';
  static const _kLevel = 'level';
  static const _kNama = 'nama_asli';

  static Future<void> saveLogin({
    required int idUsers,
    required String username,
    required String level,
    required String namaAsli,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kId, idUsers);
    await sp.setString(_kUsername, username);
    await sp.setString(_kLevel, level);
    await sp.setString(_kNama, namaAsli);
  }

  static Future<bool> isLoggedIn() async {
    final sp = await SharedPreferences.getInstance();
    return sp.containsKey(_kId);
  }

  static Future<Map<String, dynamic>?> currentUser() async {
    final sp = await SharedPreferences.getInstance();
    if (!sp.containsKey(_kId)) return null;
    return {
      'id_users': sp.getInt(_kId),
      'username': sp.getString(_kUsername),
      'level': sp.getString(_kLevel),
      'nama_asli': sp.getString(_kNama),
    };
  }

  static Future<void> logout() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kId);
    await sp.remove(_kUsername);
    await sp.remove(_kLevel);
    await sp.remove(_kNama);
  }
}
