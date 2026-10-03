import 'job.dart';

import '../utils/dates.dart';

/// A builder → mazdoor job invitation.
/// Backend shape: {id, jobId, mazdoorId, builderId, trade, wageOffer,
///   status: invited|accepted|declined|removed,
///   createdAt, updatedAt, respondedAt}
class JobApplication {
  final String id;
  final String jobId;
  final String workerId; // mazdoorId
  final String workerName;
  final double workerRating;
  final String trade;
  final String status;
  final Job? job; // populated client-side from GET /api/jobs/:id
  final DateTime? createdAt;

  const JobApplication({
    required this.id,
    required this.jobId,
    required this.workerId,
    required this.workerName,
    this.workerRating = 0,
    required this.trade,
    this.status = 'invited',
    this.job,
    this.createdAt,
  });

  bool get isPending => status == 'invited' || status == 'requested';

  JobApplication copyWith(
          {Job? job, String? workerName, double? workerRating}) =>
      JobApplication(
        id: id,
        jobId: jobId,
        workerId: workerId,
        workerName: workerName ?? this.workerName,
        workerRating: workerRating ?? this.workerRating,
        trade: trade,
        status: status,
        job: job ?? this.job,
        createdAt: createdAt,
      );

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    final jobJson = json['job'];
    return JobApplication(
      id: (json['id'] ?? '').toString(),
      jobId: (json['jobId'] ?? '').toString(),
      workerId: (json['mazdoorId'] ?? json['workerId'] ?? '').toString(),
      workerName: (json['workerName'] ?? '').toString(),
      workerRating: (json['workerRating'] as num?)?.toDouble() ?? 0,
      trade: (json['trade'] ?? '').toString(),
      status: (json['status'] ?? 'invited').toString(),
      job: jobJson is Map
          ? Job.fromJson(Map<String, dynamic>.from(jobJson))
          : null,
      createdAt: json['createdAt'] != null
          ? parseApiDateTime(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'jobId': jobId,
        'mazdoorId': workerId,
        'trade': trade,
        'status': status,
      };
}
