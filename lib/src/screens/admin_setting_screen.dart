// lib/src/screens/admin_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../services/db.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers (SharedPreferences)
  final _namaCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();
  final _telpCtrl = TextEditingController();
  final _pajakCtrl = TextEditingController(); // persen pajak (0..100)
  bool _autoPrint = false;

  // Controllers (WiFi / DB)
  final _wifiNamaCtrl = TextEditingController();
  final _wifiPassCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _alamatCtrl.dispose();
    _telpCtrl.dispose();
    _pajakCtrl.dispose();
    _wifiNamaCtrl.dispose();
    _wifiPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);

    try {
      // Load dari SharedPreferences
      final sp = await SharedPreferences.getInstance();
      _namaCtrl.text = sp.getString('toko_nama') ?? 'TEMEJI CAFE';
      _alamatCtrl.text = sp.getString('toko_alamat') ?? 'Jl. Contoh Alamat No. 1';
      _telpCtrl.text = sp.getString('toko_telp') ?? '08xx-xxxx-xxxx';
      _autoPrint = sp.getBool('auto_print') ?? false;
      final pajak = sp.getDouble('pajak_persen') ?? 0.0;
      _pajakCtrl.text = pajak.toString();

      // Load WiFi (ambil baris pertama)
      final db = await AppDatabase().database;
      final wifi = await db.query('wifi', limit: 1);
      if (wifi.isNotEmpty) {
        _wifiNamaCtrl.text = (wifi.first['nama_wifi'] ?? '') as String;
        _wifiPassCtrl.text = (wifi.first['pass_wifi'] ?? '') as String;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat pengaturan: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      // Simpan SharedPreferences
      final sp = await SharedPreferences.getInstance();
      await sp.setString('toko_nama', _namaCtrl.text.trim());
      await sp.setString('toko_alamat', _alamatCtrl.text.trim());
      await sp.setString('toko_telp', _telpCtrl.text.trim());
      await sp.setBool('auto_print', _autoPrint);
      final pajak = double.tryParse(_pajakCtrl.text.replaceAll(',', '.')) ?? 0.0;
      await sp.setDouble('pajak_persen', pajak);

      // Simpan WiFi (insert/update single row)
      final db = await AppDatabase().database;
      await db.transaction((txn) async {
        final rows = await txn.query('wifi', limit: 1);
        final data = {
          'nama_wifi': _wifiNamaCtrl.text.trim(),
          'pass_wifi': _wifiPassCtrl.text.trim(),
        };
        if (rows.isEmpty) {
          await txn.insert('wifi', data);
        } else {
          final id = rows.first['id_wifi'] as int;
          await txn.update('wifi', data, where: 'id_wifi = ?', whereArgs: [id]);
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan disimpan')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Toko')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Informasi Toko',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _namaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Toko',
                      prefixIcon: Icon(Icons.store_mall_directory_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _alamatCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Alamat',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    maxLines: 2,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _telpCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Telepon',
                      prefixIcon: Icon(Icons.call_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pajakCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Persen Pajak (%)',
                            prefixIcon: Icon(Icons.percent),
                          ),
                          validator: (v) {
                            final d =
                                double.tryParse((v ?? '').replaceAll(',', '.'));
                            if (d == null || d < 0) return 'Tidak valid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto Print'),
                          value: _autoPrint,
                          onChanged: (v) => setState(() => _autoPrint = v),
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 32),

                  Text('WiFi (untuk catatan internal / display)',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _wifiNamaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama WiFi (SSID)',
                      prefixIcon: Icon(Icons.wifi),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _wifiPassCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Password WiFi',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),

                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveAll,
                    icon: _saving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('SIMPAN'),
                  ),
                ],
              ),
            ),
    );
  }
}
