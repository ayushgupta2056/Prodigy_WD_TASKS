/// Calendar-date helpers. All dates in the app are plain calendar days
/// (no time, no time zone), stored as 'YYYY-MM-DD' and handled as UTC
/// midnight [DateTime]s so arithmetic never trips over DST or zones.
library;

DateTime day(int y, int m, int d) => DateTime.utc(y, m, d);

DateTime? parseIso(String? s) {
  if (s == null || s.isEmpty) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (m == null) return null;
  return DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

String toIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Today in the device's local calendar, as a UTC-midnight date.
DateTime today([DateTime? now]) {
  final n = now ?? DateTime.now();
  return DateTime.utc(n.year, n.month, n.day);
}

DateTime addDays(DateTime d, int n) => DateTime.utc(d.year, d.month, d.day + n);

int daysBetween(DateTime a, DateTime b) => b.difference(a).inDays;

DateTime startOfWeek(DateTime d) => addDays(d, -(d.weekday - 1)); // Monday
DateTime startOfMonth(DateTime d) => DateTime.utc(d.year, d.month, 1);
DateTime addMonths(DateTime d, int n) => DateTime.utc(d.year, d.month + n, 1);
DateTime startOfQuarter(DateTime d) => DateTime.utc(d.year, ((d.month - 1) ~/ 3) * 3 + 1, 1);
DateTime startOfYear(DateTime d) => DateTime.utc(d.year, 1, 1);

/// Number of overlapping nights between [a1,a2) and [b1,b2).
int overlapNights(DateTime a1, DateTime a2, DateTime b1, DateTime b2) {
  final s = a1.isAfter(b1) ? a1 : b1;
  final e = a2.isBefore(b2) ? a2 : b2;
  final n = daysBetween(s, e);
  return n > 0 ? n : 0;
}

Iterable<DateTime> eachNight(DateTime start, DateTime endExclusive) sync* {
  for (var d = start; d.isBefore(endExclusive); d = addDays(d, 1)) {
    yield d;
  }
}
