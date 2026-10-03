import 'package:intl/intl.dart';

import '../utils/dates.dart';

/// One trade line inside a job's team request.
/// Backend shape: tradesRequired: [{trade, count, wageOffer}]
class TradeRequirement {
  final String trade; // canonical English trade id, e.g. 'Mason'
  final int count;
  final double dailyWage;

  const TradeRequirement({
    required this.trade,
    required this.count,
    required this.dailyWage,
  });

  factory TradeRequirement.fromJson(Map<String, dynamic> json) {
    return TradeRequirement(
      trade: (json['trade'] ?? '').toString(),
      count: (json['count'] as num?)?.toInt() ?? 1,
      dailyWage:
          ((json['dailyWage'] ?? json['wageOffer']) as num?)?.toDouble() ?? 0,
    );
  }

  /// Serialized for POST /api/jobs as {trade, count, wageOffer}.
  Map<String, dynamic> toJson() => {
        'trade': trade,
        'count': count,
        'wageOffer': dailyWage,
      };
}

/// A construction job posted by a builder, requesting a multi-trade team.
///
/// Backend shape:
/// {id, builderId, title, description, tradesRequired, tradeList,
///  siteLocation: {lat,lng}, city, startDate, expectedDays, status,
///  assignedTeam: [{mazdoorId,trade,dailyWage}], assignedTeamIds,
///  createdAt, updatedAt}
class Job {
  final String id;
  final String builderId;
  final String title;
  final String description;
  final String city;
  final double siteLat;
  final double siteLng;
  final List<TradeRequirement> trades;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? expectedDays;
  final String
      status; // draft|open|assigned|in_progress|completed|closed|cancelled
  final List<String> assignedWorkerIds;
  final DateTime? createdAt;

  const Job({
    required this.id,
    required this.builderId,
    required this.title,
    required this.description,
    this.city = '',
    required this.siteLat,
    required this.siteLng,
    this.trades = const [],
    this.startDate,
    this.endDate,
    this.expectedDays,
    this.status = 'open',
    this.assignedWorkerIds = const [],
    this.createdAt,
  });

  /// Display label for the site — falls back to the city.
  String get siteName => city;

  int get totalWorkersNeeded => trades.fold(0, (sum, t) => sum + t.count);

  double get totalDailyWage =>
      trades.fold(0.0, (sum, t) => sum + t.count * t.dailyWage);

  bool get isOpen => status == 'open' || status == 'draft';
  bool get isActive => status == 'in_progress' || status == 'assigned';
  bool get isDone =>
      status == 'completed' || status == 'closed' || status == 'cancelled';

  factory Job.fromJson(Map<String, dynamic> json) {
    final siteLoc = json['siteLocation'];
    double? siteLat;
    double? siteLng;
    if (siteLoc is Map) {
      final m = Map<String, dynamic>.from(siteLoc);
      siteLat = (m['lat'] as num?)?.toDouble();
      siteLng = (m['lng'] as num?)?.toDouble();
    }
    final startDate =
        json['startDate'] != null ? parseApiDateTime(json['startDate']) : null;
    DateTime? endDate =
        json['endDate'] != null ? parseApiDateTime(json['endDate']) : null;
    final expectedDays = (json['expectedDays'] as num?)?.toInt();
    if (endDate == null && startDate != null && expectedDays != null) {
      endDate = startDate.add(Duration(days: expectedDays));
    }
    return Job(
      id: (json['id'] ?? '').toString(),
      builderId: (json['builderId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      city: (json['city'] ?? json['siteName'] ?? '').toString(),
      siteLat: siteLat ?? (json['siteLat'] as num?)?.toDouble() ?? 0,
      siteLng: siteLng ?? (json['siteLng'] as num?)?.toDouble() ?? 0,
      trades: ((json['tradesRequired'] ?? json['trades']) as List?)
              ?.map((e) => TradeRequirement.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const <TradeRequirement>[],
      startDate: startDate,
      endDate: endDate,
      expectedDays: expectedDays,
      status: (json['status'] ?? 'open').toString(),
      assignedWorkerIds:
          ((json['assignedTeamIds'] ?? json['assignedWorkerIds']) as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const <String>[],
      createdAt: json['createdAt'] != null
          ? parseApiDateTime(json['createdAt'])
          : null,
    );
  }

  /// POST body for /api/jobs:
  /// {title, description, tradesRequired, siteLat, siteLng, city,
  ///  startDate (YYYY-MM-DD), expectedDays}.
  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'tradesRequired': trades.map((t) => t.toJson()).toList(),
        'siteLat': siteLat,
        'siteLng': siteLng,
        'city': city,
        if (startDate != null)
          'startDate': DateFormat('yyyy-MM-dd').format(startDate!),
        if (expectedDays != null) 'expectedDays': expectedDays,
      };
}
