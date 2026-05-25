import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/user_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;
  String? _ok;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _ok = null;
    });
    try {
      if (_current.text.isEmpty || _next.text.isEmpty) {
        throw 'Both fields are required.';
      }
      if (_next.text.length < 6) {
        throw 'New password must be at least 6 characters.';
      }
      if (_next.text != _confirm.text) {
        throw "New password and confirmation don't match.";
      }
      await context.read<UserService>().changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      setState(() {
        _ok = 'Password updated.';
        _current.clear();
        _next.clear();
        _confirm.clear();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _current,
                  decoration:
                      const InputDecoration(labelText: 'Current password'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _next,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    helperText: 'At least 6 characters',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirm,
                  decoration:
                      const InputDecoration(labelText: 'Confirm new password'),
                  obscureText: true,
                  onSubmitted: (_) => _save(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center),
                ],
                if (_ok != null) ...[
                  const SizedBox(height: 12),
                  Text(_ok!,
                      style: const TextStyle(color: Colors.green),
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
