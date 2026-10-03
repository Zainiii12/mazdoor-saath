import '../utils/dates.dart';

/// A daily progress log entry on a job.
/// Backend shape: {id, jobId, authorId, authorRole: builder|mazdoor,
///   date (YYYY-MM-DD), note, photoUrls[], percentComplete (0-100),
///   approved: bool|null, flagged: bool, createdAt}
class ProgressLog {
  final String id;
  final String jobId;
  final String authorId;
  final String authorRole;
  final String date; // YYYY-MM-DD
  final String note;
  final List<String> photoUrls;
  final double percentComplete;
  final bool? approved; // null = pending builder review
  final bool flagged;
  final DateTime? createdAt;

  const ProgressLog({
    required this.id,
    required this.jobId,
    required this.authorId,
    this.authorRole = 'mazdoor',
    required this.date,
    this.note = '',
    this.photoUrls = const [],
    this.percentComplete = 0,
    this.approved,
    this.flagged = false,
    this.createdAt,
  });

  /// Backwards-compatible getters for screens that showed worker/photo/caption.
  String get workerId => authorId;
  String get workerName => authorId;
  String get caption => note;
  String get photoUrl => photoUrls.isNotEmpty ? photoUrls.first : '';

  bool get isCheckIn => note.trim().toLowerCase() == 'check-in';
  bool get hasPhotos => photoUrls.isNotEmpty;

  factory ProgressLog.fromJson(Map<String, dynamic> json) {
    return ProgressLog(
      id: (json['id'] ?? '').toString(),
      jobId: (json['jobId'] ?? '').toString(),
      authorId: (json['authorId'] ?? json['workerId'] ?? '').toString(),
      authorRole: (json['authorRole'] ?? 'mazdoor').toString(),
      date: (json['date'] ?? '').toString(),
      note: (json['note'] ?? json['caption'] ?? '').toString(),
      photoUrls: (json['photoUrls'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['photoUrl'] != null && json['photoUrl'].toString().isNotEmpty
              ? [json['photoUrl'].toString()]
              : const <String>[]),
      percentComplete: (json['percentComplete'] as num?)?.toDouble() ?? 0,
      approved: json['approved'] as bool?,
      flagged: (json['flagged'] as bool?) ?? false,
      createdAt: json['createdAt'] != null
          ? parseApiDateTime(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'note': note,
        'photoUrls': photoUrls,
        'percentComplete': percentComplete,
      };
}
