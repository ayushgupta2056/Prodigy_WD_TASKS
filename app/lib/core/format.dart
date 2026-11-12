import 'package:intl/intl.dart';

/// ₹1,23,456 (Indian grouping). Whole rupees unless [decimals] is set.
String inr(num? value, {int decimals = 0, bool sign = false}) {
  if (value == null) return '—';
  final neg = value < 0;
  final abs = value.abs();
  final fixed = abs.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final grouped = groupIndian(parts[0]);
  final frac = parts.length > 1 ? '.${parts[1]}' : '';
  final prefix = neg ? '−' : (sign && value > 0 ? '+' : '');
  return '$prefix₹$grouped$frac';
}

/// '1234567' -> '12,34,567'
String groupIndian(String digits) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '${groups.join(',')},$last3';
}

/// Short form for chart axes: ₹1.2L, ₹3.4Cr, ₹12K.
String inrCompact(num value) {
  final a = value.abs();
  final s = value < 0 ? '−' : '';
  if (a >= 1e7) return '$s₹${_trim(a / 1e7)}Cr';
  if (a >= 1e5) return '$s₹${_trim(a / 1e5)}L';
  if (a >= 1e3) return '$s₹${_trim(a / 1e3)}K';
  return '$s₹${a.round()}';
}

String _trim(double v) => v >= 100 ? v.round().toString() : v.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');

String pct(num? value, {int decimals = 0}) => value == null ? '—' : '${value.toStringAsFixed(decimals)}%';

/// 12 Nov 2026
String fmtDate(DateTime? d) => d == null ? '—' : DateFormat('dd MMM yyyy').format(d);

/// 12 Nov
String fmtDayMonth(DateTime d) => DateFormat('d MMM').format(d);

/// "12–16 Nov" or "28 Nov – 2 Dec" or across years with the year.
String fmtRange(DateTime a, DateTime b) {
  if (a.year != b.year) return '${DateFormat('d MMM yyyy').format(a)} – ${DateFormat('d MMM yyyy').format(b)}';
  if (a.month == b.month) return '${a.day}–${b.day} ${DateFormat('MMM').format(b)}';
  return '${fmtDayMonth(a)} – ${fmtDayMonth(b)}';
}

String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

/// "Rahul Sharma" -> "Rahul S."
String shortName(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'Guest';
  if (parts.length == 1) return parts[0];
  return '${parts.first} ${parts.last[0].toUpperCase()}.';
}

/// Parse what a user typed into an amount field: "12,450", "₹ 900", "1.5".
double? parseAmountInput(String s) {
  final cleaned = s.replaceAll(RegExp(r'[₹,\s]|Rs\.?|INR', caseSensitive: false), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}
