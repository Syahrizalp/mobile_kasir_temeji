import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/db.dart';
import '../services/session.dart';
import 'login_screen.dart';

class FinanceHomeScreen extends StatefulWidget {
  const FinanceHomeScreen({super.key});

  @override
  State<FinanceHomeScreen> createState() => _FinanceHomeScreenState();
}

class _FinanceHomeScreenState extends State<FinanceHomeScreen> {
  double pendapatanHariIni = 0;
  int jumlahTransaksi = 0;
  int jumlahMenuTerjual = 0;
  List<Map<String, Object?>> transaksiList = [];

  final _fmtRp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await AppDatabase().database;

    // Ringkasan harian
    final summary = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(total_harga),0) as totalPendapatan,
        COUNT(*) as jumlahTransaksi
      FROM transaksi
      WHERE DATE(tanggal_transaksi) = DATE('now')
    ''');

    // Total item terjual (kuantitas)
    final sold = await db.rawQuery('''
      SELECT COALESCE(SUM(d.kuantitas),0) as totalMenuTerjual
      FROM detail_transaksi d
      JOIN transaksi t ON d.id_transaksi = t.id_transaksi
      WHERE DATE(t.tanggal_transaksi) = DATE('now')
    ''');

    // Daftar transaksi hari ini
    final trxList = await db.rawQuery('''
      SELECT t.id_transaksi, t.tanggal_transaksi, t.total_harga
      FROM transaksi t
      WHERE DATE(t.tanggal_transaksi) = DATE('now')
      ORDER BY t.tanggal_transaksi DESC
    ''');

    setState(() {
      pendapatanHariIni = (summary.first['totalPendapatan'] as num).toDouble();
      jumlahTransaksi = (summary.first['jumlahTransaksi'] as int?) ?? 0;
      jumlahMenuTerjual = (sold.first['totalMenuTerjual'] as int?) ?? 0;
      transaksiList = trxList;
    });
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final bool? konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
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
      appBar: AppBar(
        title: const Text('Finance - Dashboard'),
        actions: [
          IconButton(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ====== STAT CARDS (HORIZONTAL / RESPONSIF) ======
            LayoutBuilder(
              builder: (context, constraints) {
                // Pakai Wrap agar otomatis turun baris di layar kecil
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      icon: Icons.attach_money,
                      label: 'Pendapatan Hari Ini',
                      value: _fmtRp.format(pendapatanHariIni),
                      // lebar fleksibel: bagi tiga untuk layar lebar, atau full jika sempit
                      width: _calcStatWidth(constraints.maxWidth),
                    ),
                    _StatCard(
                      icon: Icons.receipt_long,
                      label: 'Jumlah Transaksi',
                      value: '$jumlahTransaksi',
                      width: _calcStatWidth(constraints.maxWidth),
                    ),
                    _StatCard(
                      icon: Icons.fastfood,
                      label: 'Menu Terjual',
                      value: '$jumlahMenuTerjual',
                      width: _calcStatWidth(constraints.maxWidth),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),
            const Text('Transaksi Hari Ini', style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),

            // ====== LIST TRANSAKSI ======
            if (transaksiList.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Belum ada transaksi hari ini')),
              )
            else
              ...transaksiList.map((trx) {
                final id = trx['id_transaksi'];
                final tgl = trx['tanggal_transaksi'];
                final total = (trx['total_harga'] as num?) ?? 0;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.shopping_cart_outlined),
                    title: Text('$id'),
                    subtitle: Text('$tgl'),
                    trailing: Text(_fmtRp.format(total)),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // Hitung lebar tiap kartu agar 3 kolom di layar lebar, 2 kolom di medium, 1 kolom di kecil
  double _calcStatWidth(double maxWidth) {
    if (maxWidth >= 980) {
      // tiga kolom
      return (maxWidth - 24) / 3; // 24 = 2 * spacing(12)
    } else if (maxWidth >= 640) {
      // dua kolom
      return (maxWidth - 12) / 2;
    } else {
      // satu kolom
      return maxWidth;
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double width;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width, // penting untuk Wrap agar horizontal
      child: Card(
        elevation: 2,
        child: Container(
          height: 110,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
             Container(
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 28,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
