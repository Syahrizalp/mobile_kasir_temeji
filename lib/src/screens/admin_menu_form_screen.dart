import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/menu.dart';
import '../repositories/menu_dao.dart';

class AdminMenuFormScreen extends StatefulWidget {
  final MenuItem? existing;
  const AdminMenuFormScreen({super.key, this.existing});

  @override
  State<AdminMenuFormScreen> createState() => _AdminMenuFormScreenState();
}

class _AdminMenuFormScreenState extends State<AdminMenuFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _hargaCtrl = TextEditingController();
  final _stokCtrl = TextEditingController(text: '0');
  final _kategoriCtrl = TextEditingController();
  final _ukuranCtrl = TextEditingController();

  final _dao = MenuDao();
  String? _pathGambar;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _namaCtrl.text = e.namaMenu;
      _hargaCtrl.text = e.harga.toStringAsFixed(0);
      _stokCtrl.text = e.stok.toString();
      _kategoriCtrl.text = e.kategori;
      _ukuranCtrl.text = e.ukuranMenu;
      _pathGambar = e.pathGambar;
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _hargaCtrl.dispose();
    _stokCtrl.dispose();
    _kategoriCtrl.dispose();
    _ukuranCtrl.dispose();
    super.dispose();
  }

  Future<String> _copyToAppDir(File src) async {
    final docs = await getApplicationDocumentsDirectory();
    final ext = p.extension(src.path);
    final name = 'menu_${DateTime.now().millisecondsSinceEpoch}$ext';
    final dest = File(p.join(docs.path, name));
    return (await src.copy(dest.path)).path;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final copiedPath = await _copyToAppDir(File(picked.path));
    setState(() => _pathGambar = copiedPath);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pathGambar == null || _pathGambar!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih gambar menu')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final item = MenuItem(
        idMenu: widget.existing?.idMenu,
        namaMenu: _namaCtrl.text.trim(),
        harga: double.tryParse(_hargaCtrl.text.trim()) ?? 0,
        stok: int.tryParse(_stokCtrl.text.trim()) ?? 0,
        kategori: _kategoriCtrl.text.trim(),
        ukuranMenu: _ukuranCtrl.text.trim(),
        pathGambar: _pathGambar!,
      );

      if (widget.existing == null) {
        await _dao.insert(item);
      } else {
        await _dao.update(item);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Menu' : 'Tambah Menu')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Preview & pilih gambar
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black12,
                    image: _pathGambar != null
                        ? DecorationImage(
                            image: FileImage(File(_pathGambar!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _pathGambar == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_outlined, size: 48),
                            SizedBox(height: 8),
                            Text('Tap untuk pilih gambar'),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _namaCtrl,
                decoration: const InputDecoration(labelText: 'Nama Menu'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _hargaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return 'Masukkan angka yang valid';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _stokCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stok'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                  final n = int.tryParse(v);
                  if (n == null || n < 0) return 'Masukkan angka bulat ≥ 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _kategoriCtrl,
                decoration: const InputDecoration(labelText: 'Kategori'),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _ukuranCtrl,
                decoration: const InputDecoration(labelText: 'Ukuran'),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('SIMPAN'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
