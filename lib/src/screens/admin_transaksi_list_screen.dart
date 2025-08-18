// lib/src/screens/admin_transaksi_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../services/db.dart';

class AdminTransaksiListScreen extends StatefulWidget {
  const AdminTransaksiListScreen({super.key});

  @override
  State<AdminTransaksiListScreen> createState() => _AdminTransaksiListScreenState();
}

class _AdminTransaksiListScreenState extends State<AdminTransaksiListScreen> {
  final _searchCtrl = TextEditingController();

  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to = DateTime.now();

  bool _loading = false;
  List<_TrxRow> _rows = [];

  final _fmtDateTime = DateFormat('yyyy-MM-dd HH:mm:ss');
  final _fmtDisp = DateFormat('dd MMM yyyy HH:mm', 'id_ID');
  final _fmtMoney = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: 'Pilih Rentang Tanggal',
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) {
      setState(() {
        // gunakan 00:00:00 s/d 23:59:59
        _from = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        _to   = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = await AppDatabase().database;

      // Build WHERE
      final whereArgs = <Object?>[];
      final where = StringBuffer();
      // by date range
      where.write('(datetime(tanggal_transaksi) >= datetime(?) AND datetime(tanggal_transaksi) <= datetime(?))');
      whereArgs.add(_fmtDateTime.format(_from));
      whereArgs.add(_fmtDateTime.format(_to));

      // by keyword
      final q = _searchCtrl.text.trim();
      if (q.isNotEmpty) {
        where.write(' AND (');
        where.write('t.id_transaksi LIKE ? OR u.nama_asli LIKE ? OR u.username LIKE ?');
        where.write(')');
        final wildcard = '%$q%';
        whereArgs.addAll([wildcard, wildcard, wildcard]);
      }

      // Query ringkasan transaksi + kasir + total item
      final list = await db.rawQuery('''
        SELECT
          t.id_transaksi,
          t.tanggal_transaksi,
          t.total_harga,
          t.uang_pembayaran,
          t.uang_kembalian,
          u.nama_asli AS kasir_nama,
          u.username  AS kasir_username,
          (
            SELECT IFNULL(SUM(d.kuantitas), 0)
            FROM detail_transaksi d
            WHERE d.id_transaksi = t.id_transaksi
          ) AS total_item
        FROM transaksi t
        JOIN users u ON u.id_users = t.id_users
        WHERE ${where.toString()}
        ORDER BY datetime(t.tanggal_transaksi) DESC
      ''', whereArgs);

      _rows = list.map((e) => _TrxRow.fromMap(e)).toList();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat transaksi: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetail(String idTransaksi) async {
    try {
      final db = await AppDatabase().database;
      final details = await db.rawQuery('''
        SELECT
          d.kuantitas,
          d.subtotal,
          m.nama_menu,
          m.harga
        FROM detail_transaksi d
        LEFT JOIN menu m ON m.id_menu = d.id_menu
        WHERE d.id_transaksi = ?
      ''', [idTransaksi]);

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 4, width: 48, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 12),
                Text('Detail Transaksi $idTransaksi', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: details.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final r = details[i];
                      final nama = (r['nama_menu'] ?? '-') as String;
                      final harga = (r['harga'] as num?)?.toDouble() ?? 0;
                      final qty = (r['kuantitas'] as num?)?.toInt() ?? 0;
                      final sub = (r['subtotal'] as num?)?.toDouble() ?? 0;
                      return ListTile(
                        title: Text(nama),
                        subtitle: Text('$qty x ${_fmtMoney.format(harga)}'),
                        trailing: Text(_fmtMoney.format(sub), style: const TextStyle(fontWeight: FontWeight.w600)),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal buka detail: $e')),
      );
    }
  }

  Future<void> _pullToRefresh() => _load();

  @override
  Widget build(BuildContext context) {
    final rangeText =
        '${DateFormat('dd MMM yyyy', 'id_ID').format(_from)}  —  ${DateFormat('dd MMM yyyy', 'id_ID').format(_to)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Semua Transaksi'),
      ),
      body: Column(
        children: [
          // Filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Cari: ID / Nama kasir / Username',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: () { _searchCtrl.clear(); _load(); },
                        icon: const Icon(Icons.clear),
                      ),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(rangeText),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List transaksi
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _pullToRefresh,
                    child: _rows.isEmpty
                        ? const Center(child: Text('Tidak ada transaksi'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemBuilder: (ctx, i) {
                              final r = _rows[i];
                              return Card(
                                elevation: 1,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blueGrey.shade100,
                                    child: const Icon(Icons.receipt_long, color: Colors.black87),
                                  ),
                                  title: Text(r.idTransaksi, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_fmtDisp.format(r.tanggal)),
                                      Text('Kasir: ${r.kasirNama} (@${r.kasirUsername})'),
                                      Text('Item: ${r.totalItem}'),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(_fmtMoney.format(r.totalHarga),
                                          style: const TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text('Bayar ${_fmtMoney.format(r.uangPembayaran)}'),
                                      Text('Kembali ${_fmtMoney.format(r.uangKembalian)}'),
                                    ],
                                  ),
                                  onTap: () => _openDetail(r.idTransaksi),
                                ),
                              );
                            },
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemCount: _rows.length,
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ----------------- Model ringkas baris transaksi -----------------
class _TrxRow {
  final String idTransaksi;
  final DateTime tanggal;
  final double totalHarga;
  final double uangPembayaran;
  final double uangKembalian;
  final String kasirNama;
  final String kasirUsername;
  final int totalItem;

  _TrxRow({
    required this.idTransaksi,
    required this.tanggal,
    required this.totalHarga,
    required this.uangPembayaran,
    required this.uangKembalian,
    required this.kasirNama,
    required this.kasirUsername,
    required this.totalItem,
  });

  factory _TrxRow.fromMap(Map<String, Object?> m) {
    // tanggal_transaksi di DB kamu bertipe TEXT 'yyyy-MM-dd HH:mm:ss'
    final tStr = (m['tanggal_transaksi'] ?? '') as String;
    final parsed = DateTime.tryParse(tStr.replaceFirst(' ', 'T')) ?? DateTime.now();

    return _TrxRow(
      idTransaksi: (m['id_transaksi'] ?? '') as String,
      tanggal: parsed,
      totalHarga: (m['total_harga'] as num?)?.toDouble() ?? 0.0,
      uangPembayaran: (m['uang_pembayaran'] as num?)?.toDouble() ?? 0.0,
      uangKembalian: (m['uang_kembalian'] as num?)?.toDouble() ?? 0.0,
      kasirNama: (m['kasir_nama'] ?? '-') as String,
      kasirUsername: (m['kasir_username'] ?? '-') as String,
      totalItem: (m['total_item'] as num?)?.toInt() ?? 0,
    );
  }
}
