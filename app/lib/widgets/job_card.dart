import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/job.dart';
import '../providers/app_state.dart';

/// Summary card for a job in lists.
class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback? onTap;
  final String? distanceLabel;

  const JobCard({
    super.key,
    required this.job,
    this.onTap,
    this.distanceLabel,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
      case 'matching':
        return Colors.blue;
      case 'in_progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final dateFmt = DateFormat.yMMMd(appState.locale == 'ur' ? 'ur' : 'en');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(job.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      appState.statusLabel(job.status),
                      style: TextStyle(
                        color: _statusColor(job.status),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: job.trades
                    .map((t) => Chip(
                          label: Text(
                            '${appState.tradeName(t.trade)} × ${t.count}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.siteName,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (distanceLabel != null) ...[
                    const Icon(Icons.directions_walk, size: 16),
                    const SizedBox(width: 2),
                    Text(distanceLabel!,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
              if (job.startDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      dateFmt.format(job.startDate!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      ' · ${job.totalWorkersNeeded} ${appState.t('workers')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
