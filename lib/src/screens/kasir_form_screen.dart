// lib/src/screens/kasir_form_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/session.dart';
import '../services/db.dart';
import '../repositories/menu_dao.dart';
import '../models/menu.dart';
import 'login_screen.dart';

/// Baris item di keranjang
class _CartLine {
  final int idMenu;
  final String nama;
  final double harga;
  int qty;
  final String? imgPath;

  _CartLine({
    required this.idMenu,
    required this.nama,
    required this.harga,
    this.qty = 1,
    this.imgPath,
  });

  double get subtotal => harga * qty;
}

class KasirFormScreen extends StatefulWidget {
  const KasirFormScreen({super.key});

  @override
  State<KasirFormScreen> createState() => _KasirFormScreenState();
}

class _KasirFormScreenState extends State<KasirFormScreen> {
  final _menuDao = MenuDao();

  // Katalog & pencarian
  final _searchCtrl = TextEditingController();
  List<MenuItem> _katalog = [];
  bool _loadingKatalog = false;

  // Keranjang
  final Map<int, _CartLine> _cart = {}; // key: id_menu
  final _bayarCtrl = TextEditingController();

  double get _total =>
      _cart.values.fold<double>(0.0, (p, e) => p + e.subtotal);

  double get _bayar =>
      double.tryParse(_bayarCtrl.text.replaceAll(',', '.')) ?? 0.0;

  double get _kembali => _bayar - _total;

  // Waktu & Kasir
  late Timer _timer;
  DateTime _now = DateTime.now();
  String _kasirName = '-';
  int? _kasirId;
  String _kasirLevel = '-';

  @override
  void initState() {
    super.initState();
    _initKasir();
    _loadKatalog();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _searchCtrl.dispose();
    _bayarCtrl.dispose();
    super.dispose();
  }

  Future<void> _initKasir() async {
    final u = await Session.currentUser();
    setState(() {
      _kasirName =
          (u?['nama_asli'] as String?) ?? (u?['username'] as String? ?? '-');
      _kasirLevel = (u?['level'] as String?) ?? '-';
      _kasirId = u?['id_users'] as int?;
    });
  }

  Future<void> _loadKatalog({String? keyword}) async {
    setState(() => _loadingKatalog = true);
    try {
      final list = await _menuDao.getAll(keyword: keyword);
      setState(() => _katalog = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat menu: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingKatalog = false);
    }
  }

  // ------------------- Keranjang -------------------
  void _addToCart(MenuItem m) {
    if (m.idMenu == null) return;
    final line = _cart[m.idMenu!] ??
        _CartLine(
          idMenu: m.idMenu!,
          nama: m.namaMenu,
          harga: m.harga,
          imgPath: m.pathGambar,
          qty: 0,
        );
    line.qty += 1;
    setState(() => _cart[m.idMenu!] = line);
  }

  void _decFromCart(int idMenu) {
    final line = _cart[idMenu];
    if (line == null) return;
    if (line.qty <= 1) {
      setState(() => _cart.remove(idMenu));
    } else {
      setState(() => line.qty -= 1);
    }
  }

  void _removeLine(int idMenu) {
    setState(() => _cart.remove(idMenu));
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _bayarCtrl.clear();
    });
  }

  // ------------------- Simpan transaksi -------------------
  Future<void> _confirmPayment() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang masih kosong')),
      );
      return;
    }
    if (_bayar < _total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uang bayar kurang dari total')),
      );
      return;
    }
    if (_kasirId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session kasir tidak valid')),
      );
      return;
    }

    final now = DateTime.now();
    final idTrx = 'TRX${DateFormat('yyyyMMddHHmmss').format(now)}';

    try {
      await AppDatabase().inTransaction((txn) async {
        // Pajak 0 dulu; tinggal sesuaikan jika dibutuhkan
        const persenPajak = 0.0;
        const pajak = 0.0;
        final totalSetelah = _total + pajak;

        await txn.insert('transaksi', {
          'id_transaksi': idTrx,
          'id_users': _kasirId!,
          'tanggal_transaksi': DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
          'total_harga': totalSetelah,
          'uang_pembayaran': _bayar,
          'uang_kembalian': _bayar - _total,
          'id_pembeli': 'WALKIN',
          'metode': 'cash',
          'PersenPajak': persenPajak,
          'pajak': pajak,
          'Total_setelah_Pajak': totalSetelah,
        });

        for (final line in _cart.values) {
          await txn.insert('detail_transaksi', {
            'id_transaksi': idTrx,
            'id_menu': line.idMenu,
            'kuantitas': line.qty,
            'subtotal': line.subtotal,
          });

          // Kurangi stok (tidak negatif)
          await txn.rawUpdate(
            'UPDATE menu SET stok = CASE WHEN stok >= ? THEN stok - ? ELSE 0 END WHERE id_menu = ?',
            [line.qty, line.qty, line.idMenu],
          );
        }

        // Log (opsional)
        await txn.insert('log_aktivitas', {
          'id_users': _kasirId!,
          'keterangan': 'Transaksi $idTrx total $_total',
          'tanggal': DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pembayaran berhasil (ID: $idTrx)')),
      );
      _clearCart();
      _loadKatalog(
        keyword: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal simpan transaksi: $e')),
      );
    }
  }

  // ------------------- Logout -------------------
  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Session.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false,
      );
    }
  }

  // ------------------- UI -------------------
  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final fmtDate = DateFormat('EEEE, dd MMM yyyy HH:mm', 'id_ID');

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Kasir'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('$_kasirName • $_kasirLevel'),
            ),
          ),
          IconButton(onPressed: _confirmLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Row(
        children: [
          // KIRI: waktu, katalog, pencarian
          Expanded(
            flex: 6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time),
                      const SizedBox(width: 8),
                      Text(
                        fmtDate.format(_now),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),

                // Pencarian
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Cari menu...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          _loadKatalog();
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    ),
                    onSubmitted: (q) => _loadKatalog(keyword: q.trim()),
                  ),
                ),

                // Katalog (grid)
                Expanded(
                  child: _loadingKatalog
                      ? const Center(child: CircularProgressIndicator())
                      : _katalog.isEmpty
                          ? const Center(child: Text('Tidak ada menu'))
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isTablet ? 4 : 2,
                                  childAspectRatio: 1.1,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: _katalog.length,
                                itemBuilder: (context, i) {
                                  final m = _katalog[i];
                                  final imgOk = m.pathGambar.isNotEmpty &&
                                      File(m.pathGambar).existsSync();
                                  final qty = _cart[m.idMenu!]?.qty ?? 0;

                                  return Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      onTap: () => _addToCart(m),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                top: Radius.circular(12),
                                              ),
                                              child: imgOk
                                                  ? Image.file(
                                                      File(m.pathGambar),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : Container(
                                                      color:
                                                          Colors.grey.shade200,
                                                      child: const Icon(
                                                        Icons
                                                            .image_not_supported_outlined,
                                                        size: 48,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  m.namaMenu,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  NumberFormat.currency(
                                                    locale: 'id_ID',
                                                    symbol: 'Rp ',
                                                  ).format(m.harga),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons
                                                          .remove_circle_outline),
                                                      onPressed: qty > 0
                                                          ? () => _decFromCart(
                                                              m.idMenu!)
                                                          : null,
                                                    ),
                                                    Text('$qty'),
                                                    IconButton(
                                                      icon: const Icon(Icons
                                                          .add_circle_outline),
                                                      onPressed: () =>
                                                          _addToCart(m),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),

          // KANAN: keranjang & pembayaran
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                border:
                    Border(left: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Keranjang',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _cart.isEmpty
                        ? const Center(child: Text('Belum ada item'))
                        : ListView.separated(
                            itemCount: _cart.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final line = _cart.values.elementAt(i);
                              final hasImg =
                                  (line.imgPath?.isNotEmpty ?? false) &&
                                      File(line.imgPath!).existsSync();
                              return ListTile(
                                leading: hasImg
                                    ? ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        child: Image.file(
                                          File(line.imgPath!),
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: Icon(Icons.image_outlined),
                                      ),
                                title: Text(line.nama),
                                subtitle: Text(
                                  '${line.qty} x ${NumberFormat.currency(locale: "id_ID", symbol: "Rp ").format(line.harga)}',
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      NumberFormat.currency(
                                        locale: 'id_ID',
                                        symbol: 'Rp ',
                                      ).format(line.subtotal),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          _removeLine(line.idMenu),
                                      child: const Text(
                                        'Hapus',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _rowKV(
                          'Total',
                          NumberFormat.currency(
                            locale: 'id_ID',
                            symbol: 'Rp ',
                          ).format(_total),
                          bold: true,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _bayarCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Uang Dibayar',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        _rowKV(
                          'Kembalian',
                          NumberFormat.currency(
                            locale: 'id_ID',
                            symbol: 'Rp ',
                          ).format(_kembali.isFinite && _kembali > 0 ? _kembali : 0),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    _cart.isEmpty ? null : _clearCart,
                                child: const Text('REMOVE'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: _cart.isEmpty
                                    ? null
                                    : _confirmPayment,
                                child: const Text('CONFIRM PAYMENT'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowKV(String k, String v, {bool bold = false}) {
    final s = TextStyle(
      fontSize: 16,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );
    return Row(
      children: [
        Expanded(child: Text(k, style: s)),
        Text(v, style: s),
      ],
    );
  }
}
