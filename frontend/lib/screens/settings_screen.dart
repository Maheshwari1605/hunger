import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_service.dart';
import 'users_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _cafeName;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _gst;
  late final TextEditingController _footer;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsService>().settings;
    _cafeName = TextEditingController(text: s?.cafeName ?? 'Hunger Cafe');
    _address = TextEditingController(text: s?.address ?? '');
    _phone = TextEditingController(text: s?.phone ?? '');
    _gst = TextEditingController(text: s?.gstNumber ?? '');
    _footer = TextEditingController(text: s?.receiptFooter ?? '');
  }

  @override
  void dispose() {
    _cafeName.dispose();
    _address.dispose();
    _phone.dispose();
    _gst.dispose();
    _footer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<SettingsService>().update({
        // Tax-free POS — always send 0 so older records get reset on the server.
        'taxRate': 0,
        'cafeName': _cafeName.text,
        'address': _address.text,
        'phone': _phone.text,
        'gstNumber': _gst.text,
        'receiptFooter': _footer.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Outlet settings',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _cafeName,
          decoration: const InputDecoration(labelText: 'Cafe name'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          decoration: const InputDecoration(labelText: 'Phone'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _address,
          decoration: const InputDecoration(labelText: 'Address'),
          maxLines: 2,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _gst,
          decoration: const InputDecoration(labelText: 'GST number'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _footer,
          decoration: const InputDecoration(labelText: 'Receipt footer'),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_saving ? 'Saving…' : 'Save'),
        ),
        const SizedBox(height: 28),
        Text('Staff', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.group_outlined),
            title: const Text('Manage users'),
            subtitle: const Text('Add cashier / kitchen / admin accounts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UsersScreen()),
            ),
          ),
        ),
      ],
    );
  }
}
