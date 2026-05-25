import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late Future<List<StaffUser>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = context.read<UserService>().list();
    });
  }

  Future<void> _addUser() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _UserDialog(),
    );
    if (created == true) _reload();
  }

  Future<void> _editUser(StaffUser u) async {
    final selfId = context.read<AuthService>().user?.id;
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _UserDialog(existing: u, isSelf: u.id == selfId),
    );
    if (updated == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff users')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUser,
        icon: const Icon(Icons.person_add),
        label: const Text('Add user'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<StaffUser>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Error: ${snap.error}'),
                  ),
                ],
              );
            }
            final users = snap.data ?? const [];
            if (users.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('No users yet.')),
                ],
              );
            }
            return ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final u = users[i];
                return ListTile(
                  leading: CircleAvatar(child: Text(_initials(u.name))),
                  title: Text('${u.name}${u.active ? '' : ' (disabled)'}'),
                  subtitle: Text('${u.email} · ${u.role}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editUser(u),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final a = parts.first[0];
    final b = parts.length > 1 ? parts.last[0] : '';
    return (a + b).toUpperCase();
  }
}

/// Single dialog used for both Create and Edit.
class _UserDialog extends StatefulWidget {
  final StaffUser? existing;
  final bool isSelf;
  const _UserDialog({this.existing, this.isSelf = false});

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late String _role;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _password = TextEditingController();
    _role = e?.role ?? 'cashier';
    _active = e?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final svc = context.read<UserService>();
      if (widget.existing == null) {
        if (_name.text.trim().isEmpty ||
            _email.text.trim().isEmpty ||
            _password.text.isEmpty) {
          throw 'Name, email and password are required.';
        }
        await svc.create(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          role: _role,
        );
      } else {
        await svc.update(
          widget.existing!.id,
          name: _name.text.trim(),
          role: _role,
          active: _active,
          newPassword:
              _password.text.isEmpty ? null : _password.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Edit user' : 'New user'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _email,
                enabled: !editing, // email is the natural key — don't allow rename
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _password,
                decoration: InputDecoration(
                  labelText:
                      editing ? 'Reset password (leave blank to keep)' : 'Password',
                  helperText: 'At least 6 characters',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                  DropdownMenuItem(value: 'kitchen', child: Text('Kitchen')),
                ],
                onChanged: widget.isSelf
                    ? null // can't demote self
                    : (v) => setState(() => _role = v ?? 'cashier'),
              ),
              if (editing) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: Text(widget.isSelf
                      ? "Can't deactivate yourself."
                      : 'Disabled users cannot log in.'),
                  value: _active,
                  onChanged: widget.isSelf
                      ? null
                      : (v) => setState(() => _active = v),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
