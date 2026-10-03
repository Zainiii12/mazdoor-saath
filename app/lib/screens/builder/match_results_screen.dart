import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/match_result.dart';
import '../../providers/app_state.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/worker_card.dart';

/// Ranked mazdoor matches for a job (GET /api/jobs/:id/matches) with
/// per-trade invite buttons (POST /api/jobs/:id/invite).
class MatchResultsScreen extends StatefulWidget {
  final String jobId;
  const MatchResultsScreen({super.key, required this.jobId});

  @override
  State<MatchResultsScreen> createState() => _MatchResultsScreenState();
}

class _MatchResultsScreenState extends State<MatchResultsScreen> {
  late Future<List<MatchResult>> _matchesFuture;
  final Set<String> _invited = {};
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _matchesFuture = _load();
  }

  Future<List<MatchResult>> _load() async {
    final api = context.read<AppState>().api;
    final data = await api.get('/api/jobs/${widget.jobId}/matches');
    // The envelope is unwrapped by ApiClient; backend returns
    // {jobId, radiusKm, count, matches: [...]}.
    final matches = (data as Map)['matches'] as List? ?? const [];
    return matches
        .map((e) => MatchResult.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _invite(MatchResult match) async {
    final appState = context.read<AppState>();
    final t = appState.t;
    setState(() => _busyId = match.workerId);
    try {
      await appState.api.post('/api/jobs/${widget.jobId}/invite', {
        'mazdoorId': match.workerId,
        'trade': match.trades.isNotEmpty ? match.trades.first : '',
      });
      if (!mounted) return;
      setState(() {
        _invited.add(match.workerId);
        _busyId = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('inviteSent'))));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t('errorGeneric')}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppState>().t;
    return Scaffold(
      appBar: AppBar(title: Text(t('findMatches'))),
      body: FutureBuilder<List<MatchResult>>(
        future: _matchesFuture,
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
                    onPressed: () => setState(() => _matchesFuture = _load()),
                    child: Text(t('retry')),
                  ),
                ],
              ),
            );
          }
          final matches = snap.data ?? [];
          if (matches.isEmpty) {
            return EmptyState(
              icon: Icons.person_search_outlined,
              message: t('noNearbyJobs'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: matches.length,
            itemBuilder: (context, i) {
              final m = matches[i];
              return WorkerCard(
                match: m,
                invited: _invited.contains(m.workerId),
                inviteBusy: _busyId == m.workerId,
                onInvite: () => _invite(m),
              );
            },
          );
        },
      ),
    );
  }
}
