import 'package:flutter/material.dart';
import '../repositories/user_dao.dart';

class AdminUserUpsertScreen extends StatefulWidget {
  /// null = tambah user; ada isi = edit user
  final Map<String, dynamic>? existing;
  const AdminUserUpsertScreen({super.key, this.existing});

  @override
  State<AdminUserUpsertScreen> createState() => _AdminUserUpsertScreenState();
}

class _AdminUserUpsertScreenState extends State<AdminUserUpsertScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _namaCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _password2Ctrl = TextEditingController();

  final _dao = UserDao();

  bool _isEdit = false;
  bool _showPw = false;
  bool _resetPassword = false;
  bool _saving = false;
  String _level = 'kasir';

  @override
  void initState() {
    super.initState();
    _isEdit = widget.existing != null;
    if (_isEdit) {
      final r = widget.existing!;
      _usernameCtrl.text = (r['username'] as String?) ?? '';
      _namaCtrl.text = (r['nama_asli'] as String?) ?? '';
      _level = (r['level'] as String?) ?? 'kasir';
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _namaCtrl.dispose();
    _passwordCtrl.dispose();
    _password2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        final id = widget.existing!['id_users'] as int;
        await _dao.updateProfile(
          idUsers: id,
          username: _usernameCtrl.text.trim(),
          level: _level,
          namaAsli: _namaCtrl.text.trim(),
        );
        if (_resetPassword) {
          await _dao.changePassword(idUsers: id, newPassword: _passwordCtrl.text);
        }
      } else {
        await _dao.register(
          username: _usernameCtrl.text.trim(),
          password: _passwordCtrl.text,
          level: _level,
          namaAsli: _namaCtrl.text.trim(),
        );
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
    final title = _isEdit ? 'Edit User' : 'Tambah User';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Username
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Username wajib diisi';
                  if (v.contains(' ')) return 'Tidak boleh ada spasi';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Nama asli
              TextFormField(
                controller: _namaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama asli',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),

              // Level
              DropdownButtonFormField<String>(
                value: _level,
                decoration: const InputDecoration(
                  labelText: 'Level',
                  prefixIcon: Icon(Icons.security_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('admin')),
                  DropdownMenuItem(value: 'kasir', child: Text('kasir')),
                  DropdownMenuItem(value: 'finance', child: Text('finance')),
                  DropdownMenuItem(value: 'owner', child: Text('owner')),
                ],
                onChanged: (v) => setState(() => _level = v ?? 'kasir'),
              ),
              const SizedBox(height: 16),

              // Password section
              if (!_isEdit) ...[
                _PasswordField(
                  controller: _passwordCtrl,
                  label: 'Password',
                  show: _showPw,
                  onToggle: () => setState(() => _showPw = !_showPw),
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: _password2Ctrl,
                  label: 'Ulangi Password',
                  show: _showPw,
                  onToggle: () => setState(() => _showPw = !_showPw),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ulangi password';
                    if (v != _passwordCtrl.text) return 'Tidak sama dengan password';
                    return null;
                  },
                ),
              ],

              if (_isEdit) ...[
                SwitchListTile.adaptive(
                  value: _resetPassword,
                  onChanged: (v) => setState(() => _resetPassword = v),
                  title: const Text('Setel ulang password'),
                  subtitle: const Text('Aktifkan untuk mengisi password baru'),
                ),
                if (_resetPassword) ...[
                  _PasswordField(
                    controller: _passwordCtrl,
                    label: 'Password baru',
                    show: _showPw,
                    onToggle: () => setState(() => _showPw = !_showPw),
                    validator: (v) {
                      if (!_resetPassword) return null;
                      if (v == null || v.isEmpty) return 'Password baru wajib diisi';
                      if (v.length < 4) return 'Minimal 4 karakter';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _PasswordField(
                    controller: _password2Ctrl,
                    label: 'Ulangi password baru',
                    show: _showPw,
                    onToggle: () => setState(() => _showPw = !_showPw),
                    validator: (v) {
                      if (!_resetPassword) return null;
                      if (v == null || v.isEmpty) return 'Ulangi password baru';
                      if (v != _passwordCtrl.text) return 'Tidak sama dengan password baru';
                      return null;
                    },
                  ),
                ],
              ],

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

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool show;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.show,
    required this.onToggle,
    this.validator,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !show,
      validator: validator ??
          (v) {
            if (v == null || v.isEmpty) return 'Password wajib diisi';
            if (v.length < 4) return 'Minimal 4 karakter';
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(show ? Icons.visibility : Icons.visibility_off),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
