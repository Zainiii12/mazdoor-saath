import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/ledger_entry.dart';
import '../../providers/app_state.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_title.dart';

/// Mazdoor's own wage ledger across all jobs (GET /api/ledger/mine).
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  late Future<List<LedgerEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<LedgerEntry>> _load() async {
    final api = context.read<AppState>().api;
    // Newest first per the backend; same entry shape as the per-job GET.
    final data = await api.get('/api/ledger/mine');
    var entries = ((data as List?) ?? const [])
        .map((e) => LedgerEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    // Resolve job titles for display (best effort).
    final titles = <String, String>{};
    await Future.wait(entries.map((e) => e.jobId).toSet().map((jobId) async {
      try {
        final job =
            Map<String, dynamic>.from(await api.get('/api/jobs/$jobId'));
        titles[jobId] = (job['title'] ?? '').toString();
      } catch (_) {}
    }));
    entries =
        entries.map((e) => e.copyWith(jobTitle: titles[e.jobId])).toList();

    entries.sort((a, b) {
      final cmp = b.date.compareTo(a.date);
      if (cmp != 0) return cmp;
      return (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000));
    });
    return entries;
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final t = appState.t;
    final dateFmt = DateFormat.yMMMd(appState.locale == 'ur' ? 'ur' : 'en');

    return Scaffold(
      appBar: AppBar(title: Text(t('earnings'))),
      body: FutureBuilder<List<LedgerEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t('errorGeneric')),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _refresh, child: Text(t('retry'))),
                ],
              ),
            );
          }
          final entries = snap.data ?? [];
          final earned = entries.fold(0.0, (s, e) => s + e.signedAmount);
          final paid = entries
              .where((e) => e.isPaid)
              .fold(0.0, (s, e) => s + e.signedAmount);

          if (entries.isEmpty) {
            return EmptyState(
                icon: Icons.payments_outlined, message: t('noLedger'));
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _SumCard(
                          label: t('totalWages'),
                          value: earned,
                          color: Colors.blue),
                      const SizedBox(width: 8),
                      _SumCard(
                          label: t('totalPaid'),
                          value: paid,
                          color: Colors.green),
                      const SizedBox(width: 8),
                      _SumCard(
                          label: t('pending'),
                          value: earned - paid,
                          color: Colors.orange),
                    ],
                  ),
                ),
                SectionTitle(text: t('ledger')),
                ...entries.map((e) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: e.type == 'deduction'
                            ? Colors.red.withValues(alpha: 0.15)
                            : Colors.green.withValues(alpha: 0.15),
                        child: Icon(
                          e.type == 'deduction' ? Icons.remove : Icons.add,
                          color:
                              e.type == 'deduction' ? Colors.red : Colors.green,
                        ),
                      ),
                      title: Text(
                          '${e.jobTitle ?? t('jobDetails')} · ${t(e.type)}'),
                      subtitle: Text(
                        '${e.note.isNotEmpty ? '${e.note} · ' : ''}${e.date.isNotEmpty ? e.date : (e.createdAt != null ? dateFmt.format(e.createdAt!) : '')}',
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rs ${e.signedAmount.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            e.isPaid ? t('paid') : t('unpaid'),
                            style: TextStyle(
                              fontSize: 11,
                              color: e.isPaid ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SumCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SumCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            children: [
              Text(
                'Rs ${value.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
