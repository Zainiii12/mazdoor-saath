import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/job.dart';
import '../../providers/app_state.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/job_card.dart';
import '../../widgets/section_title.dart';
import '../common/profile_screen.dart';

/// Builder dashboard: stats, my jobs, post-job shortcut.
class BuilderHomeScreen extends StatefulWidget {
  const BuilderHomeScreen({super.key});

  @override
  State<BuilderHomeScreen> createState() => _BuilderHomeScreenState();
}

class _BuilderHomeScreenState extends State<BuilderHomeScreen> {
  late Future<List<Job>> _jobsFuture;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _jobsFuture = _loadJobs();
  }

  Future<List<Job>> _loadJobs() async {
    final api = context.read<AppState>().api;
    final data = await api.get('/api/jobs?mine=true');
    return (data as List)
        .map((e) => Job.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  void _refresh() => setState(() => _jobsFuture = _loadJobs());

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final t = appState.t;

    if (_tab == 1) {
      return Scaffold(
        body: const ProfileScreen(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          items: [
            BottomNavigationBarItem(
                icon: const Icon(Icons.home), label: t('home')),
            BottomNavigationBarItem(
                icon: const Icon(Icons.person), label: t('profile')),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t('myJobs')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<Job>>(
        future: _jobsFuture,
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
          final jobs = snap.data ?? [];
          if (jobs.isEmpty) {
            return EmptyState(
              icon: Icons.work_outline,
              message: t('noJobs'),
              actionLabel: t('postJob'),
              onAction: () => Navigator.pushNamed(context, '/builder/post')
                  .then((_) => _refresh()),
            );
          }
          final open = jobs.where((j) => j.isOpen).length;
          final active = jobs.where((j) => j.isActive).length;
          final done = jobs
              .where((j) => j.status == 'completed' || j.status == 'closed')
              .length;

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      _StatCard(
                          label: t('open'), value: open, color: Colors.blue),
                      const SizedBox(width: 8),
                      _StatCard(
                          label: t('inProgress'),
                          value: active,
                          color: Colors.orange),
                      const SizedBox(width: 8),
                      _StatCard(
                          label: t('completed'),
                          value: done,
                          color: Colors.green),
                    ],
                  ),
                ),
                SectionTitle(text: t('myJobs')),
                ...jobs.map(
                  (job) => JobCard(
                    job: job,
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/builder/job',
                      arguments: {'jobId': job.id},
                    ).then((_) => _refresh()),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/builder/post')
            .then((_) => _refresh()),
        icon: const Icon(Icons.add),
        label: Text(t('postJob')),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.home), label: t('home')),
          BottomNavigationBarItem(
              icon: const Icon(Icons.person), label: t('profile')),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
