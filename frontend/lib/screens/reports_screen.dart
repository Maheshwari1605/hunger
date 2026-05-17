import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/report_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<_ReportsBundle> _future;
  static final _money = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
  }

  Future<_ReportsBundle> _loadAll() async {
    final svc = context.read<ReportService>();
    final results = await Future.wait([
      svc.daily(),
      svc.monthly(),
      svc.bestSelling(limit: 10),
      svc.paymentMix(),
    ]);
    return _ReportsBundle(
      daily: results[0] as Map<String, dynamic>,
      monthly: results[1] as Map<String, dynamic>,
      best: results[2] as List<Map<String, dynamic>>,
      mix: results[3] as List<Map<String, dynamic>>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReportsBundle>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final b = snap.data!;
        final summary = (b.daily['summary'] as Map?) ?? {};

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _statCard('Today: Orders',
                      '${(summary['orders'] ?? 0)}', Icons.receipt_long),
                  _statCard(
                      'Today: Revenue',
                      _money.format((summary['revenue'] ?? 0).toDouble()),
                      Icons.payments),
                  _statCard(
                      'Today: Tax',
                      _money.format((summary['tax'] ?? 0).toDouble()),
                      Icons.account_balance),
                ],
              ),
              const SizedBox(height: 24),
              Text('Monthly revenue',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              SizedBox(height: 220, child: _MonthlyChart(monthly: b.monthly)),
              const SizedBox(height: 24),
              Text('Best selling items',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _BestSellersList(items: b.best),
              const SizedBox(height: 24),
              Text('Payment mix',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _PaymentMixList(mix: b.mix),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 36),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  Text(value,
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportsBundle {
  final Map<String, dynamic> daily;
  final Map<String, dynamic> monthly;
  final List<Map<String, dynamic>> best;
  final List<Map<String, dynamic>> mix;

  _ReportsBundle({
    required this.daily,
    required this.monthly,
    required this.best,
    required this.mix,
  });
}

class _MonthlyChart extends StatelessWidget {
  final Map<String, dynamic> monthly;
  const _MonthlyChart({required this.monthly});

  @override
  Widget build(BuildContext context) {
    final byDay = (monthly['byDay'] as List?) ?? const [];
    if (byDay.isEmpty) {
      return const Center(child: Text('No data for this month yet.'));
    }
    final spots = <FlSpot>[];
    for (var i = 0; i < byDay.length; i++) {
      final row = byDay[i] as Map<String, dynamic>;
      spots.add(FlSpot(i.toDouble(), (row['revenue'] as num).toDouble()));
    }
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            color: Theme.of(context).colorScheme.primary,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color:
                  Theme.of(context).colorScheme.primary.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _BestSellersList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _BestSellersList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('No sales yet.');
    return Card(
      child: Column(
        children: [
          for (final row in items)
            ListTile(
              dense: true,
              leading: const Icon(Icons.star),
              title: Text((row['name'] ?? 'Unknown').toString()),
              trailing: Text('${row['quantitySold']} sold'),
            ),
        ],
      ),
    );
  }
}

class _PaymentMixList extends StatelessWidget {
  final List<Map<String, dynamic>> mix;
  const _PaymentMixList({required this.mix});

  static final _money = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    if (mix.isEmpty) return const Text('No payments yet.');
    return Card(
      child: Column(
        children: [
          for (final row in mix)
            ListTile(
              dense: true,
              leading: const Icon(Icons.credit_card),
              title: Text((row['_id'] ?? 'unknown').toString().toUpperCase()),
              subtitle: Text('${row['orders']} orders'),
              trailing: Text(_money.format((row['revenue'] as num).toDouble())),
            ),
        ],
      ),
    );
  }
}
