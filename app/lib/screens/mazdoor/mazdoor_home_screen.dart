import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/job.dart';
import '../../models/job_application.dart';
import '../../providers/app_state.dart';
import '../../services/location_service.dart';
import '../../widgets/job_card.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/section_title.dart';
import 'earnings_screen.dart';
import '../common/profile_screen.dart';

/// Mazdoor home: pending invites, my active jobs, nearby open jobs.
/// Nearby jobs are browse-only: the backend has no worker-initiated
/// "request to join" — builders invite mazdoors directly.
class MazdoorHomeScreen extends StatefulWidget {
  const MazdoorHomeScreen({super.key});

  @override
  State<MazdoorHomeScreen> createState() => _MazdoorHomeScreenState();
}

class _MazdoorHomeScreenState extends State<MazdoorHomeScreen> {
  final _location = LocationService();
  late Future<_HomeData> _future;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final api = context.read<AppState>().api;
    final results = await Future.wait([
      // My invitations; client-side filter to pending invites.
      api.get('/api/users/me/applications'),
      // My assigned jobs (backend filters by role: mazdoor → assignedTeamIds).
      api.get('/api/jobs?mine=true'),
      // All open jobs; distance filtered client-side below.
      api.get('/api/jobs?status=open'),
    ]);

    var invites = (results[0] as List)
        .map(
            (e) => JobApplication.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((a) => a.status == 'invited')
        .toList();
    final active = (results[1] as List)
        .map((e) => Job.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((j) => j.status == 'in_progress' || j.status == 'assigned')
        .toList();

    // Attach each invite's job detail for display (title, wage, map).
    invites = await Future.wait(invites.map((inv) async {
      try {
        final jobData = await api.get('/api/jobs/${inv.jobId}');
        return inv.copyWith(
            job: Job.fromJson(Map<String, dynamic>.from(jobData as Map)));
      } catch (_) {
        return inv;
      }
    }));

    // Nearby: open jobs within 25 km of the current position.
    List<Job> nearby = [];
    try {
      final pos = await _location.currentPosition();
      nearby = (results[2] as List)
          .map((e) => Job.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((j) =>
              haversineKm(pos.latitude, pos.longitude, j.siteLat, j.siteLng) <=
              25)
          .toList();
    } catch (_) {
      // Location unavailable — nearby section stays empty.
    }

    return _HomeData(invites, active, nearby);
  }

  void _refresh() => setState(() => _future = _load());

  /// Nearby jobs are browse-only — show details with an explanatory note.
  void _showNearbyInfo(BuildContext context, Job job) {
    final t = context.read<AppState>().t;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(job.title),
        content: Text(t('nearbyInfo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('ok')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final t = appState.t;

    Widget body;
    if (_tab == 1) {
      body = const EarningsScreen();
    } else if (_tab == 2) {
      body = const ProfileScreen();
    } else {
      body = _buildHome(context, appState);
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home), label: t('home')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.payments_outlined), label: t('earnings')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.person), label: t('profile')),
        ],
      ),
    );
  }

  Widget _buildHome(BuildContext context, AppState appState) {
    final t = appState.t;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('appTitle')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: FutureBuilder<_HomeData>(
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
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              children: [
                SectionTitle(text: '${t('invites')} (${data.invites.length})'),
                if (data.invites.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(t('noInvites'),
                        style: Theme.of(context).textTheme.bodySmall),
                  )
                else
                  ...data.invites.map((inv) => Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(inv.job?.title.isNotEmpty == true
                                ? inv.job!.title.characters.first.toUpperCase()
                                : '?'),
                          ),
                          title: Text(inv.job?.title ?? t('jobDetails')),
                          subtitle: Row(
                            children: [
                              RatingStars(rating: inv.workerRating, size: 12),
                              const SizedBox(width: 6),
                              Text(appState.tradeName(inv.trade)),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/mazdoor/invite',
                            arguments: {'applicationId': inv.id},
                          ).then((_) => _refresh()),
                        ),
                      )),
                SectionTitle(
                    text: '${t('activeJobs')} (${data.active.length})'),
                if (data.active.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(t('noActiveJobs'),
                        style: Theme.of(context).textTheme.bodySmall),
                  )
                else
                  ...data.active.map((job) => JobCard(
                        job: job,
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/mazdoor/active',
                          arguments: {'jobId': job.id},
                        ).then((_) => _refresh()),
                      )),
                SectionTitle(text: t('nearbyJobs')),
                if (data.nearby.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(t('noNearbyJobs'),
                        style: Theme.of(context).textTheme.bodySmall),
                  )
                else
                  ...data.nearby.map((job) => JobCard(
                        job: job,
                        onTap: () => _showNearbyInfo(context, job),
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

class _HomeData {
  final List<JobApplication> invites;
  final List<Job> active;
  final List<Job> nearby;
  _HomeData(this.invites, this.active, this.nearby);
}
