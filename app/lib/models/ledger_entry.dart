import '../utils/dates.dart';

/// One digital wage-ledger entry.
/// Backend shape: {id, jobId, mazdoorId, date (YYYY-MM-DD), daysWorked,
///   dailyWage, advance, deduction, gross (= daysWorked*dailyWage),
///   net (= gross - advance - deduction), paid, paidAt, note,
///   createdBy, createdAt}
class LedgerEntry {
  final String id;
  final String jobId;
  final String? jobTitle; // resolved client-side from GET /api/jobs/:id
  final String workerId; // mazdoorId
  final String workerName; // resolved client-side from public profile
  final String date; // YYYY-MM-DD
  final double daysWorked;
  final double dailyWage;
  final double advance;
  final double deduction;
  final double gross;
  final double net;
  final bool isPaid;
  final String note;
  final DateTime? createdAt;
  final DateTime? paidAt;

  const LedgerEntry({
    required this.id,
    required this.jobId,
    this.jobTitle,
    required this.workerId,
    this.workerName = '',
    this.date = '',
    this.daysWorked = 0,
    this.dailyWage = 0,
    this.advance = 0,
    this.deduction = 0,
    this.gross = 0,
    this.net = 0,
    this.isPaid = false,
    this.note = '',
    this.createdAt,
    this.paidAt,
  });

  /// Display amount (what the worker is owed for this entry).
  double get amount => net;

  /// Backwards-compatible signed amount for total calculations.
  double get signedAmount => net;

  /// Rough entry kind for display: entries with a deduction highlight red.
  String get type => deduction > 0 ? 'deduction' : 'wage';

  LedgerEntry copyWith({String? jobTitle, String? workerName}) => LedgerEntry(
        id: id,
        jobId: jobId,
        jobTitle: jobTitle ?? this.jobTitle,
        workerId: workerId,
        workerName: workerName ?? this.workerName,
        date: date,
        daysWorked: daysWorked,
        dailyWage: dailyWage,
        advance: advance,
        deduction: deduction,
        gross: gross,
        net: net,
        isPaid: isPaid,
        note: note,
        createdAt: createdAt,
        paidAt: paidAt,
      );

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      id: (json['id'] ?? '').toString(),
      jobId: (json['jobId'] ?? '').toString(),
      jobTitle: json['jobTitle']?.toString(),
      workerId: (json['mazdoorId'] ?? json['workerId'] ?? '').toString(),
      workerName: (json['workerName'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      daysWorked: (json['daysWorked'] as num?)?.toDouble() ?? 0,
      dailyWage: (json['dailyWage'] as num?)?.toDouble() ?? 0,
      advance: (json['advance'] as num?)?.toDouble() ?? 0,
      deduction: (json['deduction'] as num?)?.toDouble() ?? 0,
      gross: (json['gross'] as num?)?.toDouble() ?? 0,
      net: (json['net'] as num?)?.toDouble() ?? 0,
      isPaid: (json['paid'] ?? json['isPaid']) as bool? ?? false,
      note: (json['note'] ?? '').toString(),
      createdAt: json['createdAt'] != null
          ? parseApiDateTime(json['createdAt'])
          : null,
      paidAt: json['paidAt'] != null ? parseApiDateTime(json['paidAt']) : null,
    );
  }

  /// POST body for /api/jobs/:id/ledger:
  /// {mazdoorId, date, daysWorked, dailyWage, advance, deduction, paid, note}.
  Map<String, dynamic> toJson() => {
        'mazdoorId': workerId,
        'date': date,
        'daysWorked': daysWorked,
        'dailyWage': dailyWage,
        'advance': advance,
        'deduction': deduction,
        'paid': isPaid,
        'note': note,
      };
}
