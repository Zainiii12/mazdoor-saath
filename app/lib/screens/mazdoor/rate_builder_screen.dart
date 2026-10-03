import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../widgets/rating_stars.dart';

/// Mazdoor rates the builder after a job → POST /api/jobs/:id/ratings.
class RateBuilderScreen extends StatefulWidget {
  final String jobId;
  final String builderId;
  final String builderName;

  const RateBuilderScreen({
    super.key,
    required this.jobId,
    required this.builderId,
    required this.builderName,
  });

  @override
  State<RateBuilderScreen> createState() => _RateBuilderScreenState();
}

class _RateBuilderScreenState extends State<RateBuilderScreen> {
  final _commentCtrl = TextEditingController();
  int _stars = 5;
  bool _submitting = false;
  String? _builderName; // resolved from GET /api/users/:id (public profile)

  @override
  void initState() {
    super.initState();
    _loadBuilderName();
  }

  Future<void> _loadBuilderName() async {
    try {
      final data = await context
          .read<AppState>()
          .api
          .get('/api/users/${widget.builderId}');
      if (!mounted) return;
      setState(() => _builderName = (data as Map)['name']?.toString());
    } catch (_) {
      // Name stays as the passed fallback.
    }
  }

  String get _displayName =>
      _builderName ??
      (widget.builderName.isNotEmpty ? widget.builderName : '—');

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = context.read<AppState>().t;
    setState(() => _submitting = true);
    try {
      await context
          .read<AppState>()
          .api
          .post('/api/jobs/${widget.jobId}/ratings', {
        'rateeId': widget.builderId,
        'stars': _stars,
        'comment': _commentCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('ratingSubmitted'))));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${t('errorGeneric')}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<AppState>().t;
    return Scaffold(
      appBar: AppBar(title: Text(t('rateBuilder'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CircleAvatar(
              radius: 36,
              child: Text(
                _displayName.isNotEmpty && _displayName != '—'
                    ? _displayName.characters.first.toUpperCase()
                    : '?',
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _displayName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Text(t('yourRating'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            RatingInput(
              initial: _stars,
              onChanged: (v) => setState(() => _stars = v),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t('commentHint'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t('submitRating')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
