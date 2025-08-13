import 'package:flutter/material.dart';
import '../services/session.dart';
import 'login_screen.dart';

class PosHomeScreen extends StatelessWidget {
  const PosHomeScreen({super.key});

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
      appBar: AppBar(title: const Text('Kasir - POS'), actions: [
       IconButton(
          onPressed: () => _confirmLogout(context),
          icon: const Icon(Icons.logout),
        ),
      ]),
      body: const Center(child: Text('Layar POS / Penjualan')),
    );
  }
}
