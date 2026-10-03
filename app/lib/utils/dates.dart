/// Parses date/time values coming from the Mazdoor Sathi backend API.
///
/// The backend serializes Firestore `Timestamp` fields through `res.json()`,
/// which yields a map like `{seconds: 169..., nanoseconds: ...}` (the
/// Admin SDK's `Timestamp.toJSON()` shape). Other fields are plain strings
/// (`YYYY-MM-DD` for job dates, ISO-8601 for `createdAt`). This helper
/// accepts all of them and returns `null` when the value cannot be
/// understood, instead of throwing.
DateTime? parseApiDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  if (value is num) {
    // Epoch millis or seconds — disambiguate by magnitude.
    final ms = value > 1e12 ? value.toInt() : (value * 1000).toInt();
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }
  if (value is Map) {
    final m = Map<String, dynamic>.from(value);
    final seconds = (m['seconds'] as num?) ?? (m['_seconds'] as num?);
    if (seconds != null) {
      final nanos = (m['nanoseconds'] as num?) ??
          (m['_nanoseconds'] as num?) ??
          (m['nanos'] as num?) ??
          0;
      return DateTime.fromMillisecondsSinceEpoch(
        seconds.toInt() * 1000 + nanos.toInt() ~/ 1000000,
        isUtc: true,
      ).toLocal();
    }
    // Some serializers nest the real value under another key.
    for (final k in const ['iso', 'date', 'value', 'time']) {
      final parsed = parseApiDateTime(m[k]);
      if (parsed != null) return parsed;
    }
  }
  return null;
}
