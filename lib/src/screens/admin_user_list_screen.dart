import 'package:flutter/material.dart';
import '../repositories/user_dao.dart';
import 'admin_user_upsert_screen.dart';

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  final _dao = UserDao();
  final _searchCtrl = TextEditingController();
  String? _filterLevel; // admin|kasir|finance|owner|null
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _dao.getAll(
        keyword: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        level: _filterLevel,
        orderBy: 'username ASC',
      );
    });
  }

  Future<void> _delete(int idUsers, String username) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus User'),
        content: Text('Yakin menghapus user "$username"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _dao.deleteUser(idUsers);
      if (mounted) _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User "$username" dihapus')),
      );
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola User')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Tambah'),
        onPressed: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AdminUserUpsertScreen()),
          );
          if (changed == true && mounted) _load();
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Cari username / nama...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _filterLevel,
                  hint: const Text('Level'),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('admin')),
                    DropdownMenuItem(value: 'kasir', child: Text('kasir')),
                    DropdownMenuItem(value: 'finance', child: Text('finance')),
                    DropdownMenuItem(value: 'owner', child: Text('owner')),
                  ],
                  onChanged: (v) {
                    setState(() => _filterLevel = v);
                    _load();
                  },
                ),
                IconButton(
                  tooltip: 'Bersihkan',
                  onPressed: () {
                    _searchCtrl.clear();
                    _filterLevel = null;
                    _load();
                  },
                  icon: const Icon(Icons.clear_all),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final rows = snap.data ?? [];
                if (rows.isEmpty) {
                  return const Center(child: Text('Belum ada user'));
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final id = r['id_users'] as int;
                    final username = r['username'] as String;
                    final level = r['level'] as String;
                    final nama = r['nama_asli'] as String;

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?'),
                      ),
                      title: Text('$username • $level'),
                      subtitle: Text(nama),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              final changed = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => AdminUserUpsertScreen(existing: r),
                                ),
                              );
                              if (changed == true && mounted) _load();
                            },
                          ),
                          IconButton(
                            tooltip: 'Hapus',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(id, username),
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
