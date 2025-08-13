import 'dart:io';
import 'package:flutter/material.dart';
import '../repositories/menu_dao.dart';
import '../models/menu.dart';
import 'admin_menu_form_screen.dart';

class AdminMenuListScreen extends StatefulWidget {
  const AdminMenuListScreen({super.key});

  @override
  State<AdminMenuListScreen> createState() => _AdminMenuListScreenState();
}

class _AdminMenuListScreenState extends State<AdminMenuListScreen> {
  final _dao = MenuDao();
  final _searchCtrl = TextEditingController();
  Future<List<MenuItem>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      final kw = _searchCtrl.text.trim();
      _future = _dao.getAll(keyword: kw.isEmpty ? null : kw);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete(MenuItem m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Menu'),
        content: Text('Yakin hapus "${m.namaMenu}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _dao.delete(m.idMenu!);
      if (mounted) _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Menu "${m.namaMenu}" dihapus')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Menu')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AdminMenuFormScreen()),
          );
          if (changed == true && mounted) _load();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Cari nama menu...',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<MenuItem>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final rows = snap.data ?? [];
                if (rows.isEmpty) return const Center(child: Text('Belum ada menu'));

                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final m = rows[i];
                    final hasImage = m.pathGambar.isNotEmpty && File(m.pathGambar).existsSync();

                    return ListTile(
                      leading: hasImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(m.pathGambar),
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const SizedBox(
                              width: 56,
                              height: 56,
                              child: Icon(Icons.image_not_supported_outlined),
                            ),
                      title: Text(m.namaMenu),
                      subtitle: Text('Rp ${m.harga.toStringAsFixed(0)} • Stok ${m.stok}'
                          '${m.kategori.isNotEmpty ? ' • ${m.kategori}' : ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              final changed = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => AdminMenuFormScreen(existing: m),
                                ),
                              );
                              if (changed == true && mounted) _load();
                            },
                          ),
                          IconButton(
                            tooltip: 'Hapus',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(m),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
