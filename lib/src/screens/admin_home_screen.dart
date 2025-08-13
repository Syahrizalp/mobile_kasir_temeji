import 'package:flutter/material.dart';
import '../services/session.dart';
import 'login_screen.dart';
import 'admin_user_list_screen.dart';
import 'admin_menu_list_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final bool? konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false), // batal
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.of(ctx).pop(true), // setuju
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (konfirmasi == true) {
      await Session.logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (r) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard'), actions: [
        IconButton(
          onPressed: () => _confirmLogout(context),
          icon: const Icon(Icons.logout),
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text('Kelola User'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminUserListScreen()),
              );
            },
          ), 
          ListTile(
            leading: const Icon(Icons.restaurant_menu),
            title: const Text('Kelola Menu'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminMenuListScreen()),
              );
            },
          ),
          const ListTile(leading: Icon(Icons.receipt_long), title: Text('Semua Transaksi')),
          const ListTile(leading: Icon(Icons.settings), title: Text('Pengaturan Toko')),
        ],
      ),
    );
  }
}
