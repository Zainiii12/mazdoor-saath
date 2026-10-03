import '../utils/dates.dart';

/// A star rating between two users after a job.
class Rating {
  final String id;
  final String jobId;
  final String fromUserId;
  final String toUserId;
  final int stars; // 1..5
  final String comment;
  final DateTime? createdAt;

  const Rating({
    required this.id,
    required this.jobId,
    required this.fromUserId,
    required this.toUserId,
    required this.stars,
    this.comment = '',
    this.createdAt,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: (json['id'] ?? '').toString(),
      jobId: (json['jobId'] ?? '').toString(),
      fromUserId: (json['fromUserId'] ?? '').toString(),
      toUserId: (json['toUserId'] ?? '').toString(),
      stars: (json['stars'] as num?)?.toInt() ?? 5,
      comment: (json['comment'] ?? '').toString(),
      createdAt: json['createdAt'] != null
          ? parseApiDateTime(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'jobId': jobId,
        'toUserId': toUserId,
        'stars': stars,
        'comment': comment,
      };
}
