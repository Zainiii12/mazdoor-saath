import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/job.dart';
import '../../models/job_application.dart';
import '../../providers/app_state.dart';
import '../../widgets/section_title.dart';
import '../../widgets/urdu_mic_button.dart';

/// Mazdoor views a job invite and accepts/declines — by tap or Urdu voice.
class JobInviteScreen extends StatefulWidget {
  final String applicationId;
  const JobInviteScreen({super.key, required this.applicationId});

  @override
  State<JobInviteScreen> createState() => _JobInviteScreenState();
}

class _JobInviteScreenState extends State<JobInviteScreen> {
  late Future<JobApplication> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<JobApplication> _load() async {
    final api = context.read<AppState>().api;
    // GET /api/applications/:id returns the invitation; the job detail is
    // fetched separately (the backend does not embed it).
    final data = await api.get('/api/applications/${widget.applicationId}');
    final app = JobApplication.fromJson(Map<String, dynamic>.from(data as Map));
    final jobData = await api.get('/api/jobs/${app.jobId}');
    final job = Job.fromJson(Map<String, dynamic>.from(jobData as Map));
    return app.copyWith(job: job);
  }

  /// Respond to the invite: [action] is 'accept' or 'decline'.
  Future<void> _respond(String action) async {
    final t = context.read<AppState>().t;
    setState(() => _busy = true);
    try {
      await context.read<AppState>().api.post(
          '/api/applications/${widget.applicationId}/respond',
          {'action': action});
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('responseRecorded'))));
      if (action == 'accept') {
        final app = await _future;
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          '/mazdoor/active',
          arguments: {'jobId': app.jobId},
        );
      } else {
        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t('errorGeneric')}: $e')));
    }
  }

  /// Voice shortcut: "قبول" / "ہاں" accepts, "انکار" declines.
  void _onVoice(String text) {
    final lower = text.replaceAll(' ', '');
    if (lower.contains('قبول') || lower.contains('ہاں')) {
      _respond('accept');
    } else if (lower.contains('انکار')) {
      _respond('decline');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final t = appState.t;
    final dateFmt = DateFormat.yMMMd(appState.locale == 'ur' ? 'ur' : 'en');

    return Scaffold(
      appBar: AppBar(title: Text(t('invites'))),
      body: FutureBuilder<JobApplication>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data?.job == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t('errorGeneric')),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() => _future = _load()),
                    child: Text(t('retry')),
                  ),
                ],
              ),
            );
          }
          final app = snap.data!;
          final job = app.job!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(job.title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (job.description.isNotEmpty) Text(job.description),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 18),
                  const SizedBox(width: 4),
                  Expanded(child: Text(job.siteName)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                  '${t('selectWorker')}: ${appState.tradeName(app.trade)} · Rs ${job.trades.where((tr) => tr.trade == app.trade).map((tr) => tr.dailyWage.toStringAsFixed(0)).join(', ')} / ${appState.locale == 'ur' ? 'یوم' : 'day'}'),
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
                      interactionOptions:
                          const InteractionOptions(flags: InteractiveFlag.none),
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
              SectionTitle(text: t('status')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Chip(label: Text(appState.statusLabel(app.status))),
              ),
              if (app.isPending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : () => _respond('accept'),
                        icon: const Icon(Icons.check),
                        label: Text(t('accept')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _respond('decline'),
                        icon: const Icon(Icons.close),
                        label: Text(t('decline')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: UrduMicButton(
                    hint: t('micHint'),
                    onResult: _onVoice,
                  ),
                ),
                const SizedBox(height: 4),
                Text(t('acceptVoiceHint'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
              ] else ...[
                const SizedBox(height: 16),
                Text(
                  appState.statusLabel(app.status),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
