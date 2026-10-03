import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/job_application.dart';
import '../../models/ledger_entry.dart';
import '../../providers/app_state.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_title.dart';

/// Digital wage ledger for a job: totals, entries, add entry, mark paid.
///
/// Backend: GET /api/jobs/:id/ledger → {entries, perWorker, totals}
/// (totals: {daysWorked, gross, advance, deduction, net, paidAmount, balance});
/// POST /api/jobs/:id/ledger {mazdoorId, date, daysWorked, dailyWage,
/// advance, deduction, paid, note}; PATCH /api/ledger/:entryId {paid}.
class LedgerScreen extends StatefulWidget {
  final String jobId;
  const LedgerScreen({super.key, required this.jobId});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  late Future<_LedgerData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LedgerData> _load() async {
    final api = context.read<AppState>().api;
    final results = await Future.wait([
      api.get('/api/jobs/${widget.jobId}/ledger'),
      api.get('/api/jobs/${widget.jobId}/applications'),
    ]);
    // Envelope data: {jobId, entries, perWorker, totals}.
    final ledgerData = Map<String, dynamic>.from(results[0] as Map);
    final entries = ((ledgerData['entries'] as List?) ?? const [])
        .map((e) => LedgerEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final totals =
        Map<String, dynamic>.from((ledgerData['totals'] as Map?) ?? {});

    // Team = accepted applications (filtered client-side); resolve names.
    final apps = ((results[1] as List?) ?? const [])
        .map(
            (e) => JobApplication.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((a) => a.status == 'accepted')
        .toList();
    final team = await Future.wait(apps.map((a) async {
      try {
        final prof = Map<String, dynamic>.from(
            await api.get('/api/users/${a.workerId}'));
        return a.copyWith(
          workerName: (prof['name'] ?? '').toString(),
          workerRating: (prof['ratingAvg'] as num?)?.toDouble() ?? 0,
        );
      } catch (_) {
        return a;
      }
    }));

    // Resolve entry worker names from the team list.
    final names = {
      for (final m in team) m.workerId: m.workerName,
    };
    final namedEntries = entries
        .map((e) => e.copyWith(workerName: names[e.workerId] ?? ''))
        .toList();

    return _LedgerData(namedEntries, team, totals);
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _markPaid(LedgerEntry entry) async {
    final t = context.read<AppState>().t;
    try {
      await context
          .read<AppState>()
          .api
          .patch('/api/ledger/${entry.id}', {'paid': true});
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t('errorGeneric')}: $e')));
    }
  }

  Future<void> _showAddDialog(List<JobApplication> team) async {
    final appState = context.read<AppState>();
    final t = appState.t;
    final dateFmt = DateFormat('yyyy-MM-dd');
    String? workerId = team.isNotEmpty ? team.first.workerId : null;
    DateTime date = DateTime.now();
    final daysCtrl = TextEditingController();
    final wageCtrl = TextEditingController();
    final advanceCtrl = TextEditingController();
    final deductionCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool saving = false;

    double? parseDouble(TextEditingController c) {
      final v = double.tryParse(c.text.trim());
      return v;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(t('addEntry')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (team.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: workerId,
                    decoration: InputDecoration(
                        labelText: t('selectWorker'),
                        border: const OutlineInputBorder()),
                    items: team
                        .map((w) => DropdownMenuItem(
                              value: w.workerId,
                              child: Text(w.workerName.isNotEmpty
                                  ? w.workerName
                                  : w.workerId),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => workerId = v),
                  )
                else
                  Text(t('noActiveJobs'),
                      style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setState(() => date = picked);
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(dateFmt.format(date)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: daysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: t('daysWorked'),
                      border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: wageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: t('dailyWage'),
                      border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: advanceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: t('advance'),
                            border: const OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: deductionCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: t('deduction'),
                            border: const OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                      labelText: t('note'), border: const OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('cancel')),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final days = parseDouble(daysCtrl);
                      final wage = parseDouble(wageCtrl);
                      if (workerId == null ||
                          days == null ||
                          days <= 0 ||
                          wage == null ||
                          wage < 0) {
                        return;
                      }
                      setState(() => saving = true);
                      try {
                        await appState.api.post(
                          '/api/jobs/${widget.jobId}/ledger',
                          {
                            'mazdoorId': workerId,
                            'date': dateFmt.format(date),
                            'daysWorked': days,
                            'dailyWage': wage,
                            'advance': parseDouble(advanceCtrl) ?? 0,
                            'deduction': parseDouble(deductionCtrl) ?? 0,
                            'note': noteCtrl.text.trim(),
                          },
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text('${t('errorGeneric')}: $e')));
                        }
                        setState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(t('save')),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('entryAdded'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final t = appState.t;

    return Scaffold(
      appBar: AppBar(title: Text(t('ledger'))),
      body: FutureBuilder<_LedgerData>(
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
          final data = snap.data!;
          final entries = data.entries;
          // Totals come straight from the backend response object.
          final totals = data.totals;
          double totalOf(String k) => (totals[k] as num?)?.toDouble() ?? 0;

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _TotalCard(
                          label: t('totalWages'),
                          value: totalOf('net'),
                          color: Colors.blue),
                      const SizedBox(width: 8),
                      _TotalCard(
                          label: t('totalPaid'),
                          value: totalOf('paidAmount'),
                          color: Colors.green),
                      const SizedBox(width: 8),
                      _TotalCard(
                          label: t('pending'),
                          value: totalOf('balance'),
                          color: Colors.orange),
                    ],
                  ),
                ),
                SectionTitle(
                  text: t('ledger'),
                  trailing: TextButton.icon(
                    onPressed: () => _showAddDialog(data.team),
                    icon: const Icon(Icons.add),
                    label: Text(t('addEntry')),
                  ),
                ),
                if (entries.isEmpty)
                  EmptyState(
                      icon: Icons.receipt_long_outlined, message: t('noLedger'))
                else
                  ...entries.map((e) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: e.type == 'deduction'
                              ? Colors.red.withValues(alpha: 0.15)
                              : Colors.green.withValues(alpha: 0.15),
                          child: Icon(
                            e.type == 'deduction' ? Icons.remove : Icons.add,
                            color: e.type == 'deduction'
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                        title: Text(
                            '${e.workerName.isNotEmpty ? e.workerName : '—'} · ${e.daysWorked.toStringAsFixed(e.daysWorked.truncateToDouble() == e.daysWorked ? 0 : 1)} ${t('days')}'),
                        subtitle: Text(
                          '${e.date}${e.note.isNotEmpty ? ' · ${e.note}' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Rs ${e.net.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  e.isPaid ? t('paid') : t('unpaid'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        e.isPaid ? Colors.green : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            if (!e.isPaid)
                              TextButton(
                                onPressed: () => _markPaid(e),
                                child: Text(t('markPaid')),
                              ),
                          ],
                        ),
                      )),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final data = await _future;
          if (!mounted) return;
          _showAddDialog(data.team);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _LedgerData {
  final List<LedgerEntry> entries;
  final List<JobApplication> team;
  final Map<String, dynamic> totals;
  _LedgerData(this.entries, this.team, this.totals);
}

class _TotalCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _TotalCard(
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
