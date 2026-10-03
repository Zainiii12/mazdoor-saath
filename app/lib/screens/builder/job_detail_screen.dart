import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/job.dart';
import '../../models/job_application.dart';
import '../../providers/app_state.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/section_title.dart';

/// Builder's job detail: info, site map, status actions, team, and links to
/// matches / progress / ledger.
///
/// Status actions follow the backend STATUS_FLOW:
///   draft → open|cancelled; open → assigned|cancelled;
///   assigned → in_progress|cancelled; in_progress → completed|cancelled;
///   completed → closed.
/// Moving open → assigned sends assignedTeam: [{mazdoorId, trade, dailyWage}]
/// built from the accepted applications.
class JobDetailScreen extends StatefulWidget {
  final String jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

/// Allowed next statuses per the backend STATUS_FLOW.
const Map<String, List<String>> _statusFlow = {
  'draft': ['open', 'cancelled'],
  'open': ['assigned', 'cancelled'],
  'assigned': ['in_progress', 'cancelled'],
  'in_progress': ['completed', 'cancelled'],
  'completed': ['closed'],
  'closed': [],
  'cancelled': [],
};

class _JobDetailScreenState extends State<JobDetailScreen> {
  late Future<_Detail> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _load();
  }

  Future<_Detail> _load() async {
    final api = context.read<AppState>().api;
    final results = await Future.wait([
      api.get('/api/jobs/${widget.jobId}'),
      api.get('/api/jobs/${widget.jobId}/applications'),
    ]);
    final job = Job.fromJson(Map<String, dynamic>.from(results[0] as Map));
    final apps = (results[1] as List)
        .map(
            (e) => JobApplication.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    // Applications carry no worker display data; resolve names/ratings
    // from the public profiles (best effort).
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
    return _Detail(job, team);
  }

  void _refresh() => setState(() => _detailFuture = _load());

  Future<void> _setStatus(String status,
      {List<Map<String, dynamic>>? assignedTeam}) async {
    final t = context.read<AppState>().t;
    try {
      final body = <String, dynamic>{'status': status};
      if (assignedTeam != null) body['assignedTeam'] = assignedTeam;
      await context
          .read<AppState>()
          .api
          .patch('/api/jobs/${widget.jobId}', body);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t('errorGeneric')}: $e')));
    }
  }

  /// Builds assignedTeam: [{mazdoorId, trade, dailyWage}] from the accepted
  /// applications — required by the backend when moving open → assigned.
  Future<void> _assignTeam() async {
    final t = context.read<AppState>().t;
    final detail = await _detailFuture;
    final accepted = detail.team.where((a) => a.status == 'accepted').toList();
    if (accepted.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('noAcceptedApps'))));
      return;
    }
    final team = accepted.map((a) {
      final m = <String, dynamic>{
        'mazdoorId': a.workerId,
        'trade': a.trade,
      };
      final wage = _wageFor(a.trade, detail.job.trades);
      if (wage != null) m['dailyWage'] = wage;
      return m;
    }).toList();
    await _setStatus('assigned', assignedTeam: team);
  }

  double? _wageFor(String trade, List<TradeRequirement> trades) {
    for (final tr in trades) {
      if (tr.trade == trade) return tr.dailyWage;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final t = appState.t;

    return Scaffold(
      appBar: AppBar(title: Text(t('jobDetails'))),
      body: FutureBuilder<_Detail>(
        future: _detailFuture,
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
          final detail = snap.data!;
          final job = detail.job;
          final dateFmt =
              DateFormat.yMMMd(appState.locale == 'ur' ? 'ur' : 'en');

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(job.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    Chip(label: Text(appState.statusLabel(job.status))),
                  ],
                ),
                if (job.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(job.description),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18),
                    const SizedBox(width: 4),
                    Expanded(child: Text(job.siteName)),
                  ],
                ),
                if (job.startDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        '${dateFmt.format(job.startDate!)} → ${job.endDate != null ? dateFmt.format(job.endDate!) : '…'}'),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(job.siteLat, job.siteLng),
                        initialZoom: 14,
                        interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.mazdoor_sathi',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(job.siteLat, job.siteLng),
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_pin,
                                  color: Colors.red, size: 40),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SectionTitle(text: t('requiredTeam')),
                ...job.trades.map((tr) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.handyman_outlined),
                      title:
                          Text('${appState.tradeName(tr.trade)} × ${tr.count}'),
                      trailing: Text(
                          'Rs ${tr.dailyWage.toStringAsFixed(0)} / ${appState.locale == 'ur' ? 'یوم' : 'day'}'),
                    )),
                SectionTitle(
                  text: '${t('team')} (${detail.team.length})',
                  trailing: TextButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/builder/matches',
                      arguments: {'jobId': job.id},
                    ).then((_) => _refresh()),
                    child: Text(t('findMatches')),
                  ),
                ),
                if (detail.team.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(t('noInvites'),
                        style: Theme.of(context).textTheme.bodySmall),
                  )
                else
                  ...detail.team.map((a) => ListTile(
                        leading: CircleAvatar(
                            child: Text(a.workerName.isNotEmpty
                                ? a.workerName.characters.first.toUpperCase()
                                : '?')),
                        title: Text(a.workerName),
                        subtitle: Row(
                          children: [
                            RatingStars(rating: a.workerRating, size: 12),
                            const SizedBox(width: 6),
                            Text(appState.tradeName(a.trade)),
                          ],
                        ),
                        trailing: a.status == 'accepted'
                            ? IconButton(
                                icon: const Icon(Icons.star_outline),
                                tooltip: t('rateWorker'),
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  '/builder/rate',
                                  arguments: {
                                    'jobId': job.id,
                                    'workerId': a.workerId,
                                    'workerName': a.workerName,
                                  },
                                ),
                              )
                            : Chip(
                                label: Text(appState.statusLabel(a.status),
                                    style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                              ),
                      )),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/builder/matches',
                        arguments: {'jobId': job.id},
                      ),
                      icon: const Icon(Icons.person_search_outlined),
                      label: Text(t('findMatches')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/builder/progress',
                        arguments: {'jobId': job.id},
                      ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(t('progress')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/builder/ledger',
                        arguments: {'jobId': job.id},
                      ),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Text(t('ledger')),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(t('updateStatus'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                // Buttons follow the backend STATUS_FLOW for the current status.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (job.status == 'draft')
                      ElevatedButton(
                        onPressed: () => _setStatus('open'),
                        child: Text(t('publishJob')),
                      ),
                    if (job.status == 'open')
                      ElevatedButton(
                        onPressed: _assignTeam,
                        child: Text(t('assignTeam')),
                      ),
                    if (job.status == 'assigned')
                      ElevatedButton(
                        onPressed: () => _setStatus('in_progress'),
                        child: Text(t('startJob')),
                      ),
                    if (job.status == 'in_progress')
                      ElevatedButton(
                        onPressed: () => _setStatus('completed'),
                        child: Text(t('completeJob')),
                      ),
                    if (job.status == 'completed')
                      ElevatedButton(
                        onPressed: () => _setStatus('closed'),
                        child: Text(t('closeJob')),
                      ),
                    if ((_statusFlow[job.status] ?? const [])
                        .contains('cancelled'))
                      TextButton(
                        onPressed: () => _setStatus('cancelled'),
                        child: Text(t('cancelJob'),
                            style: const TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Detail {
  final Job job;
  final List<JobApplication> team;
  _Detail(this.job, this.team);
}
