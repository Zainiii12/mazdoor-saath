import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/match_result.dart';
import '../providers/app_state.dart';
import 'rating_stars.dart';

/// Ranked worker card on the match-results screen, with score breakdown
/// (skill / rating / proximity / availability) and an invite action.
class WorkerCard extends StatelessWidget {
  final MatchResult match;
  final VoidCallback? onInvite;
  final bool invited;
  final bool inviteBusy;

  const WorkerCard({
    super.key,
    required this.match,
    this.onInvite,
    this.invited = false,
    this.inviteBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final t = appState.t;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(match.name.isNotEmpty
                      ? match.name.characters.first.toUpperCase()
                      : '?'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      RatingStars(
                        rating: match.ratingAvg,
                        size: 14,
                        showCount: true,
                        count: match.ratingCount,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      match.score.toStringAsFixed(0),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(t('matchScore'),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                Chip(
                  label: Text(
                    match.trades
                        .map(appState.tradeName)
                        .join(', ')
                        .ifEmpty('—'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    '${match.distanceKm.toStringAsFixed(1)} ${t('kmAway')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                if (!match.isAvailable)
                  Chip(
                    label: Text(
                      '✕ ${t('available')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _ScoreBar(
                label: t('skill'),
                value: match.breakdown.skill,
                color: Colors.teal),
            _ScoreBar(
                label: t('rating'),
                value: match.breakdown.rating,
                color: Colors.amber.shade700),
            _ScoreBar(
                label: t('proximity'),
                value: match.breakdown.proximity,
                color: Colors.blue),
            _ScoreBar(
                label: t('availability'),
                value: match.breakdown.availability,
                color: Colors.green),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: invited
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check),
                      label: Text(t('invited')),
                    )
                  : ElevatedButton.icon(
                      onPressed: inviteBusy ? null : onInvite,
                      icon: inviteBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_outlined),
                      label: Text(t('invite')),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double value; // 0..1
  final Color color;

  const _ScoreBar(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              color: color,
              backgroundColor: color.withValues(alpha: 0.2),
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '${(value.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
