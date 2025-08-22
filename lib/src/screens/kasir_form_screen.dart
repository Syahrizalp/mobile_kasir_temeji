// lib/src/screens/kasir_form_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/session.dart';
import '../services/db.dart';
import '../repositories/menu_dao.dart';
import '../models/menu.dart';
import 'login_screen.dart';
import 'printer_setting_screen.dart';

// ESC/POS builder (membuat bytes struk)
import 'package:esc_pos_utils/esc_pos_utils.dart';

// Kirim ke printer (Bluetooth / Network / USB) — satu API
import 'package:flutter_pos_printer_platform/flutter_pos_printer_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // ---------- DAO / State ----------
  final _menuDao = MenuDao();

  // katalog + pencarian
  final _searchCtrl = TextEditingController();
  List<MenuItem> _katalog = [];
  bool _loadingKatalog = false;

  // keranjang
  final Map<int, _CartLine> _cart = {};
  final _bayarCtrl = TextEditingController();

  double get _total => _cart.values.fold(0.0, (p, e) => p + e.subtotal);

  double get _bayar {
    final raw = _bayarCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(raw) ?? 0.0;
  }

  double get _kembali => (_bayar - _total).clamp(0, double.infinity);

  // info kasir dari Session
  String _kasirName = '-';
  int? _kasirId;
  String _kasirLevel = '-';

  // ---------- Printer Prefs ----------
  bool _printEnabled = false;
  String? _btMac; // kalau Bluetooth dipakai
  String? _btName;
  String? _lanIp; // kalau LAN dipakai
  int? _lanPort;

  
  // hint text status printer di UI
  String get _printerStatusText {
    if (!_printEnabled) return 'Printer: Disabled';
    if ((_lanIp?.isNotEmpty ?? false) && (_lanPort ?? 0) > 0) {
      return 'Printer: LAN $_lanIp:$_lanPort';
    }
    if ((_btMac?.isNotEmpty ?? false)) {
      return 'Printer: BT ${_btName ?? _btMac}';
    }
    return 'Printer: Not configured';
  }

  @override
  void initState() {
    super.initState();
    _initKasir();
    _loadKatalog();
    _loadPrinterPrefs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _bayarCtrl.dispose();
    super.dispose();
  }

  // ---------- Dialog konfirmasi ----------
  Future<bool> _showConfirmPaymentDialog() async {
    final fmtRp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
    return (await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            final listHeight = (_cart.length <= 4) ? (_cart.length * 44.0) : 200.0;
            return AlertDialog(
              title: const Text('Konfirmasi Pembayaran'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(fmtRp.format(_total), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Bayar'),
                        Text(fmtRp.format(_bayar)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kembalian'),
                        Text(fmtRp.format(_kembali.isFinite ? _kembali : 0)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const Text('Item yang dipesan:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: listHeight,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _cart.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final it = _cart.values.elementAt(i);
                          final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
                          return Row(
                            children: [
                              Expanded(
                                child: Text(it.nama, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              Text('${it.qty} x ${fmt.format(it.harga)}'),
                              const SizedBox(width: 8),
                              Text(fmt.format(it.subtotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Batal'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.check),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  label: const Text('Lanjutkan'),
                ),
              ],
            );
          },
        )) ??
        false;
  }

  // ---------- Init ----------
  Future<void> _initKasir() async {
    final u = await Session.currentUser();
    setState(() {
      _kasirName = (u?['nama_asli'] as String?) ?? (u?['username'] as String? ?? '-');
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat menu: $e')));
    } finally {
      if (mounted) setState(() => _loadingKatalog = false);
    }
  }

  Future<void> _loadPrinterPrefs() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _printEnabled = sp.getBool('print_enabled') ?? false;

      // LAN
      _lanIp = sp.getString('printer_ip');
      final p = sp.getInt('printer_port');
      _lanPort = p == null || p <= 0 ? null : p;

      // Bluetooth
      _btMac = sp.getString('printer_mac');
      _btName = sp.getString('printer_name');
    });
  }

  // ---------- Helpers ----------
  bool _imgExists(String p) {
    try {
      return p.isNotEmpty && File(p).existsSync();
    } catch (_) {
      return false;
    }
  }

  void _addToCart(MenuItem m) {
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

  // ---------- Buat bytes struk ----------
  Future<Uint8List> _buildReceiptBytes({
    required String idTrx,
    required DateTime waktu,
    required List<_CartLine> items,
    required double total,
    required double bayar,
    required double kembali,
    String toko = 'TEMEJI CAFE',
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];

    final fmtRp = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
    final fmtDate = DateFormat('dd/MM/yyyy HH:mm');

    bytes.addAll(generator.text(
      toko,
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    ));
    bytes.addAll(generator.text('Jl. Contoh Alamat No. 1', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.text('Telp 08xx-xxxx-xxxx', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.hr());

    bytes.addAll(generator.row([
      PosColumn(text: 'Kasir', width: 4),
      PosColumn(text: ': $_kasirName', width: 8),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Tanggal', width: 4),
      PosColumn(text: ': ${fmtDate.format(waktu)}', width: 8),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'ID', width: 4),
      PosColumn(text: ': $idTrx', width: 8),
    ]));
    bytes.addAll(generator.hr());

    for (final it in items) {
      bytes.addAll(generator.text(it.nama, styles: const PosStyles(bold: true)));
      final hrg = fmtRp.format(it.harga);
      final sub = fmtRp.format(it.subtotal);
      bytes.addAll(generator.row([
        PosColumn(text: '${it.qty} x $hrg', width: 6),
        PosColumn(text: sub, width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }
    bytes.addAll(generator.hr());

    bytes.addAll(generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: fmtRp.format(total), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Bayar', width: 6),
      PosColumn(text: fmtRp.format(bayar), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Kembali', width: 6),
      PosColumn(text: fmtRp.format(kembali), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));
    bytes.addAll(generator.hr(ch: '=', linesAfter: 1));
    bytes.addAll(generator.text('Terima kasih 🙏', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return Uint8List.fromList(bytes);
  }

  // ---------- Kirim ke printer (flutter_pos_printer_platform) ----------
  Future<void> _sendToSelectedPrinter(Uint8List bytes) async {
    if (!_printEnabled) return;

    // Pakai LAN jika tersedia, selain itu fallback ke BT jika MAC ada.
    if ((_lanIp?.isNotEmpty ?? false) && (_lanPort ?? 0) > 0) {
      final model = TcpPrinterInput(ipAddress: _lanIp!, port: _lanPort!);
      await PrinterManager.instance.connect(type: PrinterType.network, model: model);
      await PrinterManager.instance.send(type: PrinterType.network, bytes: bytes);
      await PrinterManager.instance.disconnect(type: PrinterType.network);
      return;
    }

    if ((_btMac?.isNotEmpty ?? false)) {
      // Note: isBle = false untuk kebanyakan printer thermal serial BT klasik
      final model = BluetoothPrinterInput(
        name: _btName ?? 'BT-Thermal',
        address: _btMac!,
        isBle: false,
        autoConnect: true,
      );
      await PrinterManager.instance.connect(type: PrinterType.bluetooth, model: model);
      await PrinterManager.instance.send(type: PrinterType.bluetooth, bytes: bytes);
      await PrinterManager.instance.disconnect(type: PrinterType.bluetooth);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Printer belum dikonfigurasi. Buka Pengaturan Printer.')),
    );
  }

  // ---------- Simpan transaksi ----------
  Future<void> _confirmPayment() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keranjang masih kosong')));
      return;
    }
    if (_bayar < _total) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uang bayar kurang dari total')));
      return;
    }
    if (_kasirId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session kasir tidak valid')));
      return;
    }

    final setuju = await _showConfirmPaymentDialog();
    if (!setuju) return;

    final now = DateTime.now();
    final idTrx = 'TRX${DateFormat('yyyyMMddHHmmss').format(now)}';

    try {
      await AppDatabase().inTransaction((txn) async {
        const persenPajak = 0.0;
        const pajak = 0.0;
        final totalSetelah = _total + pajak;

        await txn.insert('transaksi', {
          'id_transaksi': idTrx,
          'id_users': _kasirId!,
          'tanggal_transaksi': DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
          'total_harga': totalSetelah,
          'uang_pembayaran': _bayar,
          'uang_kembalian': _kembali,
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

          await txn.rawUpdate(
            'UPDATE menu SET stok = CASE WHEN stok >= ? THEN stok - ? ELSE 0 END WHERE id_menu = ?',
            [line.qty, line.qty, line.idMenu],
          );
        }

        await txn.insert('log_aktivitas', {
          'id_users': _kasirId!,
          'keterangan': 'Transaksi $idTrx total $_total',
          'tanggal': DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
        });
      });

      // Cetak jika enabled
      if (_printEnabled) {
        final bytes = await _buildReceiptBytes(
          idTrx: idTrx,
          waktu: now,
          items: _cart.values.toList(),
          total: _total,
          bayar: _bayar,
          kembali: _kembali,
        );
        await _sendToSelectedPrinter(bytes);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pembayaran berhasil (ID: $idTrx)')));
      _clearCart();
      _loadKatalog(keyword: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal simpan transaksi: $e')));
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Keluar dari aplikasi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
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

  // ---------- UI ----------
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
          // KIRI: waktu, printer status, katalog, pencarian
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
                      StreamBuilder<int>(
                        stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
                        builder: (context, _) {
                          return Text(fmtDate.format(DateTime.now()), style: Theme.of(context).textTheme.titleMedium);
                        },
                      ),
                      const Spacer(),
                      // Status printer + tombol ke setting
                      Row(
                        children: [
                          Chip(
                            avatar: Icon(
                              _printEnabled ? Icons.print : Icons.print_disabled,
                              size: 18,
                              color: _printEnabled ? Colors.green : Colors.red,
                            ),
                            label: Text(_printerStatusText),
                          ),
                          IconButton(
                            tooltip: 'Pengaturan Printer',
                            icon: const Icon(Icons.settings),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PrinterSettingScreen()),
                              );
                              // refresh prefs ketika balik
                              await _loadPrinterPrefs();
                            },
                          ),
                        ],
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

                // Katalog (tampilkan harga + stok)
                Expanded(
                  child: _loadingKatalog
                      ? const Center(child: CircularProgressIndicator())
                      : _katalog.isEmpty
                          ? const Center(child: Text('Tidak ada menu'))
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: GridView.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isTablet ? 4 : 2,
                                  childAspectRatio: 1.1,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: _katalog.length,
                                itemBuilder: (context, i) {
                                  final m = _katalog[i];
                                  final imgOk = _imgExists(m.pathGambar);
                                  final qty = _cart[m.idMenu!]?.qty ?? 0;
                                  final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

                                  return Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: InkWell(
                                      onTap: () => _addToCart(m),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                              child: imgOk
                                                  ? Image.file(File(m.pathGambar), fit: BoxFit.cover)
                                                  : Container(
                                                      color: Colors.grey.shade200,
                                                      child: const Icon(Icons.image_not_supported_outlined, size: 48),
                                                    ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  m.namaMenu,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(fmt.format(m.harga)),
                                                const SizedBox(height: 2),
                                                Text('Stok: ${m.stok}', style: TextStyle(color: Colors.grey.shade600)),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.remove_circle_outline),
                                                      onPressed: qty > 0 ? () => _decFromCart(m.idMenu!) : null,
                                                    ),
                                                    Text('$qty'),
                                                    IconButton(
                                                      icon: const Icon(Icons.add_circle_outline),
                                                      onPressed: () => _addToCart(m),
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

          // KANAN: keranjang & payment
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey.shade300))),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Keranjang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Expanded(
                    child: _cart.isEmpty
                        ? const Center(child: Text('Belum ada item'))
                        : ListView.separated(
                            itemCount: _cart.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final line = _cart.values.elementAt(i);
                              final hasImg = _imgExists(line.imgPath ?? '');
                              final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
                              return ListTile(
                                leading: hasImg
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.file(File(line.imgPath!), width: 48, height: 48, fit: BoxFit.cover),
                                      )
                                    : const SizedBox(width: 48, height: 48, child: Icon(Icons.image_outlined)),
                                title: Text(line.nama),
                                subtitle: Text('${line.qty} x ${fmt.format(line.harga)}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(fmt.format(line.subtotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                                    TextButton(
                                      onPressed: () => _removeLine(line.idMenu),
                                      child: const Text('Hapus', style: TextStyle(color: Colors.red)),
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
                        _rowKV('Total', NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(_total), bold: true),
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
                          NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(_kembali.isFinite ? _kembali : 0),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _cart.isEmpty ? null : _clearCart,
                                child: const Text('REMOVE'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: _cart.isEmpty ? null : _confirmPayment,
                                child: const Text('CONFIRM PAYMENT'),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowKV(String k, String v, {bool bold = false}) {
    final s = TextStyle(fontSize: 16, fontWeight: bold ? FontWeight.w700 : FontWeight.w500);
    return Row(
      children: [
        Expanded(child: Text(k, style: s)),
        Text(v, style: s),
      ],
    );
  }
}
