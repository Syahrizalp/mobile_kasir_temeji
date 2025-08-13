import 'package:flutter/material.dart';
import '../services/session.dart';
import 'login_screen.dart';

class OwnerHomeScreen extends StatelessWidget {
  const OwnerHomeScreen({super.key});

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
      appBar: AppBar(title: const Text('Owner - Ringkasan'), actions: [
        IconButton(
          onPressed: () => _confirmLogout(context),
          icon: const Icon(Icons.logout),
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(leading: Icon(Icons.dashboard), title: Text('Ringkasan Penjualan')),
          ListTile(leading: Icon(Icons.trending_up), title: Text('Tren & Insight')),
          ListTile(leading: Icon(Icons.people_alt), title: Text('Performa Kasir')),
        ],
      ),
    );
  }
}
