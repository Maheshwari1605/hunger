import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/report_service.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'By Item / Category'),
              Tab(text: 'Operations'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(),
                _ItemAndCategoryTab(),
                _OperationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  late Future<_OverviewBundle> _future;
  static final _money = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_OverviewBundle> _load() async {
    final svc = context.read<ReportService>();
    final results = await Future.wait([
      svc.daily(),
      svc.monthly(),
      svc.bestSelling(limit: 10),
      svc.paymentMix(),
    ]);
    return _OverviewBundle(
      daily: results[0] as Map<String, dynamic>,
      monthly: results[1] as Map<String, dynamic>,
      best: results[2] as List<Map<String, dynamic>>,
      mix: results[3] as List<Map<String, dynamic>>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_OverviewBundle>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        final b = snap.data!;
        final summary = (b.daily['summary'] as Map?) ?? const {};
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _stat('Today: Orders', '${(summary['orders'] ?? 0)}',
                    Icons.receipt_long),
                _stat(
                    'Today: Revenue',
                    _money.format((summary['revenue'] ?? 0).toDouble()),
                    Icons.payments),
                _stat('Today: Tax',
                    _money.format((summary['tax'] ?? 0).toDouble()),
                    Icons.account_balance),
              ],
            ),
            const SizedBox(height: 20),
            Text('Monthly revenue',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            SizedBox(
              height: 200,
              child: _MonthlyChart(monthly: b.monthly),
            ),
            const SizedBox(height: 20),
            Text('Best sellers',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            if (b.best.isEmpty)
              const Text('No sales yet.')
            else
              Card(
                child: Column(
                  children: [
                    for (final r in b.best)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.star),
                        title: Text((r['name'] ?? 'Unknown').toString()),
                        trailing: Text('${r['quantitySold']} sold'),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Text('Payment mix',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            if (b.mix.isEmpty)
              const Text('No payments yet.')
            else
              Card(
                child: Column(
                  children: [
                    for (final r in b.mix)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.credit_card),
                        title: Text(
                            (r['_id'] ?? 'unknown').toString().toUpperCase()),
                        subtitle: Text('${r['orders']} orders'),
                        trailing: Text(_money.format(
                            (r['revenue'] as num).toDouble())),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 32),
              const SizedBox(width: 10),
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

class _OverviewBundle {
  final Map<String, dynamic> daily;
  final Map<String, dynamic> monthly;
  final List<Map<String, dynamic>> best;
  final List<Map<String, dynamic>> mix;
  _OverviewBundle(
      {required this.daily,
      required this.monthly,
      required this.best,
      required this.mix});
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
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Item / Category Tab ----------

class _ItemAndCategoryTab extends StatefulWidget {
  const _ItemAndCategoryTab();
  @override
  State<_ItemAndCategoryTab> createState() => _ItemAndCategoryTabState();
}

class _ItemAndCategoryTabState extends State<_ItemAndCategoryTab> {
  late Future<List<List<Map<String, dynamic>>>> _future;
  static final _money = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    final svc = context.read<ReportService>();
    _future = Future.wait([svc.categorySummary(), svc.itemSummary()]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        final cats = snap.data![0];
        final items = snap.data![1];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Category Summary',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            _table(['Category', 'Qty', 'Revenue'], [
              for (final r in cats)
                [
                  r['_id'].toString(),
                  '${r['quantity']}',
                  _money.format((r['revenue'] as num).toDouble())
                ]
            ]),
            const SizedBox(height: 20),
            Text('Item Summary',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            _table(['Item', 'Qty', 'Revenue'], [
              for (final r in items)
                [
                  r['name']?.toString() ?? '',
                  '${r['quantity']}',
                  _money.format((r['revenue'] as num).toDouble())
                ]
            ]),
          ],
        );
      },
    );
  }

  Widget _table(List<String> headers, List<List<String>> rows) {
    return Card(
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 36,
        columns: [for (final h in headers) DataColumn(label: Text(h))],
        rows: [
          for (final r in rows)
            DataRow(cells: [for (final c in r) DataCell(Text(c))]),
        ],
      ),
    );
  }
}

// ---------- Operations Tab ----------

class _OperationsTab extends StatefulWidget {
  const _OperationsTab();
  @override
  State<_OperationsTab> createState() => _OperationsTabState();
}

class _OperationsTabState extends State<_OperationsTab> {
  late Future<List<List<Map<String, dynamic>>>> _future;
  static final _money = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    final svc = context.read<ReportService>();
    _future = Future.wait([svc.orderSummary(), svc.employeeSummary()]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        final orderRows = snap.data![0];
        final employeeRows = snap.data![1];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Order Type Summary',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Card(
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 28,
                dataRowMaxHeight: 36,
                columns: const [
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Orders')),
                  DataColumn(label: Text('Revenue')),
                  DataColumn(label: Text('Avg ticket')),
                ],
                rows: [
                  for (final r in orderRows)
                    DataRow(cells: [
                      DataCell(Text(r['_id']?.toString() ?? '-')),
                      DataCell(Text('${r['orders']}')),
                      DataCell(Text(_money.format(
                          (r['revenue'] as num).toDouble()))),
                      DataCell(Text(_money.format(
                          (r['avgTicket'] as num? ?? 0).toDouble()))),
                    ]),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Employee Summary',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Card(
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 28,
                dataRowMaxHeight: 36,
                columns: const [
                  DataColumn(label: Text('Cashier')),
                  DataColumn(label: Text('Orders')),
                  DataColumn(label: Text('Revenue')),
                ],
                rows: [
                  for (final r in employeeRows)
                    DataRow(cells: [
                      DataCell(Text(r['cashierName']?.toString() ?? '—')),
                      DataCell(Text('${r['orders']}')),
                      DataCell(Text(_money.format(
                          (r['revenue'] as num).toDouble()))),
                    ]),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
