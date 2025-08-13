import 'package:flutter/material.dart';
import '../services/session.dart';
import '../screens/admin_home_screen.dart';
import '../screens/finance_home_screen.dart';
import '../screens/owner_home_screen.dart';
import '../screens/pos_home_screen.dart'; // kasir

class RoleRouter {
  /// Panggil setelah login sukses atau saat splash.
  static Future<void> goByLevel(BuildContext context, {String? level}) async {
    String? lvl = level;
    if (lvl == null) {
      final u = await Session.currentUser();
      lvl = u?['level'] as String?;
    }

    Widget page;
    switch (lvl) {
      case 'admin':
        page = const AdminHomeScreen();
        break;
      case 'kasir':
        page = const PosHomeScreen();
        break;
      case 'finance':
        page = const FinanceHomeScreen();
        break;
      case 'owner':
        page = const OwnerHomeScreen();
        break;
      default:
        page = const PosHomeScreen(); // fallback
    }

    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }
}
