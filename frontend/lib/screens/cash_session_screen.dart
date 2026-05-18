import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/cash_service.dart';

class CashSessionScreen extends StatefulWidget {
  const CashSessionScreen({super.key});

  @override
  State<CashSessionScreen> createState() => _CashSessionScreenState();
}

class _CashSessionScreenState extends State<CashSessionScreen> {
  static final _money = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
  static final _ts = DateFormat('dd MMM, HH:mm');

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<CashService>().refresh());
  }

  Future<void> _openShift() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Open shift'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Opening cash in drawer',
            prefixText: '₹ ',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context
          .read<CashService>()
          .open(double.tryParse(ctrl.text) ?? 0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _closeShift(double expected) async {
    final ctrl = TextEditingController(text: expected.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Close shift'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Expected: ${_money.format(expected)}'),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Counted cash in drawer',
                prefixText: '₹ ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context
          .read<CashService>()
          .close(double.tryParse(ctrl.text) ?? expected);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _addEntry(String type) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(type[0].toUpperCase() + type.substring(1)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final amt = double.tryParse(amount.text) ?? 0;
    if (amt <= 0) return;
    try {
      await context
          .read<CashService>()
          .addEntry(type: type, amount: amt, note: note.text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cash = context.watch<CashService>();
    final cur = cash.current;
    if (cur == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (cur['session'] == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.point_of_sale, size: 56),
              const SizedBox(height: 12),
              Text('No open cash session',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Open a shift before starting the day. This tracks all '
                'cash in and out of the drawer.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _openShift,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Open shift'),
              ),
            ],
          ),
        ),
      );
    }

    final session = cur['session'] as Map<String, dynamic>;
    final entries = (session['entries'] as List?) ?? const [];
    final cashSales = (cur['cashSalesTotal'] as num).toDouble();
    final expense = (cur['expense'] as num).toDouble();
    final withdrawal = (cur['withdrawal'] as num).toDouble();
    final topup = (cur['topup'] as num).toDouble();
    final expected = (cur['expectedCashInDrawer'] as num).toDouble();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Current shift',
                        style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => _closeShift(expected),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Close shift'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                    'Opened ${_ts.format(DateTime.parse(session['openedAt']))} by ${session['openedByName']}'),
                const Divider(),
                _row('Opening balance',
                    (session['openingBalance'] as num).toDouble()),
                _row('Cash sales', cashSales),
                _row('Top-ups', topup),
                _row('Expenses', -expense),
                _row('Withdrawals', -withdrawal),
                const Divider(),
                _row('Expected in drawer', expected, bold: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _addEntry('expense'),
                icon: const Icon(Icons.remove_shopping_cart),
                label: const Text('Expense'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _addEntry('withdrawal'),
                icon: const Icon(Icons.outbox),
                label: const Text('Withdrawal'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _addEntry('topup'),
                icon: const Icon(Icons.inbox),
                label: const Text('Top-up'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (entries.isNotEmpty)
          Card(
            child: Column(
              children: [
                const ListTile(title: Text('Entries')),
                const Divider(height: 1),
                for (final e in entries.reversed)
                  ListTile(
                    dense: true,
                    leading: Icon(_iconFor(e['type'] as String)),
                    title: Text('${e['type']} · ${_money.format((e['amount'] as num).toDouble())}'),
                    subtitle: Text(
                        '${e['note'] ?? ''}  · by ${e['byName'] ?? ''}'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(String label, double amount, {bool bold = false}) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold)
        : const TextStyle();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(_money.format(amount), style: style),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'expense':
        return Icons.remove_shopping_cart;
      case 'withdrawal':
        return Icons.outbox;
      case 'topup':
        return Icons.inbox;
      default:
        return Icons.payments;
    }
  }
}
