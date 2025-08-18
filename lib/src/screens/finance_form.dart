import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

class FinanceForm extends StatefulWidget {
  final String username;

  const FinanceForm({super.key, required this.username});

  @override
  State<FinanceForm> createState() => _FinanceFormState();
}

class _FinanceFormState extends State<FinanceForm> {
  List<Map<String, dynamic>> _transaksi = [];
  int _totalPendapatanHariIni = 0;
  int _jumlahMenuTerjual = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<Database> _openDb() async {
    final path = join(await getDatabasesPath(), "kasir.db");
    return openDatabase(path);
  }

  Future<void> _loadData() async {
    final db = await _openDb();

    // Ambil tanggal hari ini dalam format yyyy-MM-dd
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Ambil semua transaksi hari ini
    final transaksiHariIni = await db.rawQuery(
      "SELECT * FROM transaksi WHERE substr(tanggal,1,10)=?",
      [today],
    );

    // Hitung pendapatan
    final totalPendapatan = await db.rawQuery(
      "SELECT SUM(qty * harga) as total FROM transaksi WHERE substr(tanggal,1,10)=?",
      [today],
    );

    // Hitung jumlah menu terjual
    final totalQty = await db.rawQuery(
      "SELECT SUM(qty) as totalQty FROM transaksi WHERE substr(tanggal,1,10)=?",
      [today],
    );

    setState(() {
      _transaksi = transaksiHariIni;
      _totalPendapatanHariIni = (totalPendapatan.first["total"] as int?) ?? 0;
      _jumlahMenuTerjual = (totalQty.first["totalQty"] as int?) ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Finance Dashboard"),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(widget.username,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // Ringkasan Pendapatan
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text("Pendapatan Hari Ini",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("Rp $_totalPendapatanHariIni",
                          style: const TextStyle(
                              fontSize: 18, color: Colors.green)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text("Menu Terjual",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("$_jumlahMenuTerjual",
                          style: const TextStyle(
                              fontSize: 18, color: Colors.blue)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const Divider(),

          // Daftar transaksi
          Expanded(
            child: _transaksi.isEmpty
                ? const Center(child: Text("Belum ada transaksi hari ini"))
                : ListView.builder(
                    itemCount: _transaksi.length,
                    itemBuilder: (ctx, i) {
                      final t = _transaksi[i];
                      return ListTile(
                        title: Text(t["nama_menu"].toString()),
                        subtitle: Text(
                            "Qty: ${t["qty"]} x Rp ${t["harga"]} = Rp ${t["qty"] * t["harga"]}"),
                        trailing: Text(
                          t["tanggal"].toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
