/// Ranked worker match returned by GET /api/jobs/:id/matches.
class ScoreBreakdown {
  final double skill;
  final double rating;
  final double proximity;
  final double availability;

  const ScoreBreakdown({
    this.skill = 0,
    this.rating = 0,
    this.proximity = 0,
    this.availability = 0,
  });

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return ScoreBreakdown(
      skill: ((json['skill'] ?? json['tradeMatch']) as num?)?.toDouble() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      proximity: (json['proximity'] as num?)?.toDouble() ?? 0,
      // Backend calls this weight wageFit (wage fit /10).
      availability:
          ((json['availability'] ?? json['wageFit']) as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'skill': skill,
        'rating': rating,
        'proximity': proximity,
        'availability': availability,
      };
}

class MatchResult {
  final String workerId;
  final String name;
  final List<String> trades;
  final double ratingAvg;
  final int ratingCount;
  final double distanceKm;
  final double score; // 0..100
  final ScoreBreakdown breakdown;
  final bool isAvailable;
  final int yearsExperience;

  const MatchResult({
    required this.workerId,
    required this.name,
    this.trades = const [],
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.distanceKm = 0,
    this.score = 0,
    this.breakdown = const ScoreBreakdown(),
    this.isAvailable = true,
    this.yearsExperience = 0,
  });

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    // Backend shape: {mazdoor: publicProfile, distanceKm, score, breakdown}
    // Flat shape (worker fields at top level) is kept as a fallback.
    final mazdoor = json['mazdoor'];
    final worker = mazdoor is Map ? Map<String, dynamic>.from(mazdoor) : json;
    final b = json['breakdown'] ?? json['scoreBreakdown'];
    return MatchResult(
      workerId: (worker['workerId'] ?? worker['id'] ?? json['workerId'] ?? '')
          .toString(),
      name: (worker['name'] ?? json['name'] ?? '').toString(),
      trades: ((worker['trades'] ?? json['trades']) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      ratingAvg:
          ((worker['ratingAvg'] ?? json['ratingAvg']) as num?)?.toDouble() ?? 0,
      ratingCount:
          ((worker['ratingCount'] ?? json['ratingCount']) as num?)?.toInt() ??
              0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      breakdown: b is Map
          ? ScoreBreakdown.fromJson(Map<String, dynamic>.from(b))
          : const ScoreBreakdown(),
      isAvailable: (worker['isAvailable'] ??
              json['isAvailable'] ??
              worker['availability']) as bool? ??
          true,
      yearsExperience:
          ((worker['yearsExperience'] ?? json['yearsExperience']) as num?)
                  ?.toInt() ??
              0,
    );
  }

  Map<String, dynamic> toJson() => {
        'workerId': workerId,
        'name': name,
        'trades': trades,
        'ratingAvg': ratingAvg,
        'ratingCount': ratingCount,
        'distanceKm': distanceKm,
        'score': score,
        'breakdown': breakdown.toJson(),
        'isAvailable': isAvailable,
        'yearsExperience': yearsExperience,
      };
}
