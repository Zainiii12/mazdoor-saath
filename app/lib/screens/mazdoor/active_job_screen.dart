import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/job.dart';
import '../../providers/app_state.dart';
import '../../services/storage_service.dart';
import '../../widgets/section_title.dart';

/// Mazdoor's active job: site map, daily check-in, photo progress uploads,
/// and rating the builder when done.
/// Progress posts go to POST /api/jobs/:id/progress with
/// {date (YYYY-MM-DD), note, photoUrls[], percentComplete}.
class ActiveJobScreen extends StatefulWidget {
  final String jobId;
  const ActiveJobScreen({super.key, required this.jobId});

  @override
  State<ActiveJobScreen> createState() => _ActiveJobScreenState();
}

class _ActiveJobScreenState extends State<ActiveJobScreen> {
  final _storage = StorageService();
  final _picker = ImagePicker();

  late Future<Job> _future;
  bool _checkingIn = false;
  bool _uploading = false;
  double _percent = 0; // reported with every progress post

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Job> _load() async {
    final api = context.read<AppState>().api;
    final data = await api.get('/api/jobs/${widget.jobId}');
    return Job.fromJson(Map<String, dynamic>.from(data as Map));
  }

  void _refresh() => setState(() => _future = _load());

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Posts a daily check-in as a progress log entry.
  Future<void> _checkIn() async {
    final appState = context.read<AppState>();
    final t = appState.t;
    setState(() => _checkingIn = true);
    try {
      await appState.api.post('/api/jobs/${widget.jobId}/progress', {
        'date': _today,
        'note': 'check-in',
        'photoUrls': <String>[],
        'percentComplete': _percent.round(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('checkedIn'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t('errorGeneric')}: $e')));
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  /// Captures a site photo, uploads to Firebase Storage, posts progress log.
  Future<void> _uploadPhoto() async {
    final appState = context.read<AppState>();
    final t = appState.t;
    final picked =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked == null || !mounted) return;

    final captionCtrl = TextEditingController();
    final caption = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('uploadPhoto')),
        content: TextField(
          controller: captionCtrl,
          decoration: InputDecoration(
            labelText: t('addCaption'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, captionCtrl.text.trim()),
            child: Text(t('save')),
          ),
        ],
      ),
    );
    if (caption == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final url = await _storage.uploadProgressPhoto(
        jobId: widget.jobId,
        file: File(picked.path),
      );
      await appState.api.post('/api/jobs/${widget.jobId}/progress', {
        'date': _today,
        'note': caption,
        'photoUrls': [url],
        'percentComplete': _percent.round(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('photoUploaded'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t('errorGeneric')}: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final t = appState.t;

    return Scaffold(
      appBar: AppBar(title: Text(t('activeJobs'))),
      body: FutureBuilder<Job>(
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
          final job = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(job.title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18),
                    const SizedBox(width: 4),
                    Expanded(child: Text(job.siteName)),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(job.siteLat, job.siteLng),
                        initialZoom: 14,
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
                SectionTitle(text: t('updateStatus')),
                Row(
                  children: [
                    Expanded(child: Text(t('progressPct'))),
                    Text('${_percent.round()}%'),
                  ],
                ),
                Slider(
                  value: _percent,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${_percent.round()}%',
                  onChanged: (v) => setState(() => _percent = v),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _checkingIn ? null : _checkIn,
                      icon: _checkingIn
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.my_location),
                      label: Text(t('checkIn')),
                    ),
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _uploadPhoto,
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt_outlined),
                      label: Text(t('uploadPhoto')),
                    ),
                  ],
                ),
                SectionTitle(text: t('progress')),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/builder/progress',
                    arguments: {'jobId': job.id},
                  ),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(t('timeline')),
                ),
                if (job.isDone) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/mazdoor/rate',
                      arguments: {
                        'jobId': job.id,
                        'builderId': job.builderId,
                        // Builder name is resolved from GET /api/users/:id
                        // inside the rate screen.
                        'builderName': '',
                      },
                    ),
                    icon: const Icon(Icons.star_outline),
                    label: Text(t('rateBuilder')),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
