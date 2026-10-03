import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/progress_log.dart';
import '../../providers/app_state.dart';
import '../../widgets/empty_state.dart';

/// Photo timeline of daily progress (GET /api/jobs/:id/progress).
/// The builder can approve or flag entries
/// (PATCH /api/progress/:logId {approved} / {flagged}).
class ProgressTimelineScreen extends StatefulWidget {
  final String jobId;
  const ProgressTimelineScreen({super.key, required this.jobId});

  @override
  State<ProgressTimelineScreen> createState() => _ProgressTimelineScreenState();
}

class _ProgressTimelineScreenState extends State<ProgressTimelineScreen> {
  late Future<List<ProgressLog>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = _load();
  }

  Future<List<ProgressLog>> _load() async {
    final api = context.read<AppState>().api;
    final data = await api.get('/api/jobs/${widget.jobId}/progress');
    final logs = (data as List)
        .map((e) => ProgressLog.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    // Backend already returns newest first; keep a local sort as fallback.
    logs.sort((a, b) => b.date.compareTo(a.date));
    return logs;
  }

  void _refresh() => setState(() => _logsFuture = _load());

  /// Builder review: approve/reject or flag/unflag an entry.
  Future<void> _review(ProgressLog log, Map<String, dynamic> body) async {
    final t = context.read<AppState>().t;
    try {
      await context.read<AppState>().api.patch('/api/progress/${log.id}', body);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t('errorGeneric')}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final t = appState.t;
    final dateFmt =
        DateFormat.yMMMd(appState.locale == 'ur' ? 'ur' : 'en').add_jm();

    return Scaffold(
      appBar: AppBar(title: Text(t('timeline'))),
      body: FutureBuilder<List<ProgressLog>>(
        future: _logsFuture,
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
                  ElevatedButton(
                    onPressed: _refresh,
                    child: Text(t('retry')),
                  ),
                ],
              ),
            );
          }
          final logs = snap.data ?? [];
          if (logs.isEmpty) {
            return EmptyState(
                icon: Icons.photo_library_outlined, message: t('noProgress'));
          }
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              itemBuilder: (context, i) {
                final log = logs[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (log.hasPhotos)
                        SizedBox(
                          height: 200,
                          width: double.infinity,
                          child: PageView.builder(
                            itemCount: log.photoUrls.length,
                            itemBuilder: (_, p) => Image.network(
                              log.photoUrls[p],
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                height: 120,
                                child: Center(
                                    child: Icon(Icons.broken_image_outlined)),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (log.isCheckIn)
                                  Container(
                                    margin: const EdgeInsets.only(
                                        left: 0, right: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      t('checkedIn'),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    log.caption.isNotEmpty ? log.caption : '—',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  '${log.percentComplete.toStringAsFixed(0)}%',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${log.date} · ${log.createdAt != null ? dateFmt.format(log.createdAt!) : ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (log.flagged)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Chip(
                                  label: Text(t('flagged'),
                                      style: const TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor:
                                      Colors.red.withValues(alpha: 0.15),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _review(log, {'approved': true}),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: Text(t('approve')),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: log.approved == true
                                        ? Colors.green
                                        : null,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _review(log, {'approved': false}),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: Text(t('reject')),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _review(log, {'flagged': !log.flagged}),
                                  icon:
                                      const Icon(Icons.flag_outlined, size: 16),
                                  label: Text(t('flag')),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor:
                                        log.flagged ? Colors.red : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
