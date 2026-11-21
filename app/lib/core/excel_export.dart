import 'dart:typed_data';

import 'package:intl/intl.dart';

import 'dates.dart';
import 'insights.dart';
import 'models.dart';
import 'money.dart';
import 'xlsx.dart';

/// Builds the 6-sheet workbook: Summary, Bookings, Monthly, Weekly,
/// By Platform, Blocks.
///
/// [period] null = everything. [bookings] are the bookings to list on the
/// Bookings sheet (already filtered by the screen); the other sheets use
/// [data] limited to [period].
Uint8List buildExport({
  required InsightsData data,
  required Period? period,
  List<Booking>? bookings,
  DateTime? generatedAt,
}) {
  final range = period ?? _everything(data);
  final listed = (bookings ?? data.bookings)
      .where((b) => period == null || overlapNights(b.checkIn, b.checkOut, range.start, range.end) > 0 || range.contains(b.checkIn))
      .toList()
    ..sort((a, b) => a.checkIn.compareTo(b.checkIn));
  final blocks = data.blocks.where((b) => period == null || overlapNights(b.startDate, b.endExclusive, range.start, range.end) > 0).toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));

  return buildXlsx([
    _summary(data, range, period == null, generatedAt ?? DateTime.now()),
    _bookingsSheet(listed),
    _periodSheet('Monthly', data, _months(range), 'Month'),
    _periodSheet('Weekly', data, _weeks(range), 'Week starting'),
    _platformSheet(data, range),
    _blocksSheet(blocks),
  ]);
}

Period _everything(InsightsData data) {
  final starts = [...data.bookings.map((b) => b.checkIn), ...data.blocks.map((b) => b.startDate)];
  final ends = [...data.bookings.map((b) => b.checkOut), ...data.blocks.map((b) => b.endExclusive)];
  if (starts.isEmpty) {
    final t = today();
    return Period(PeriodKind.custom, startOfMonth(t), addMonths(t, 1));
  }
  starts.sort();
  ends.sort();
  return Period(PeriodKind.custom, startOfMonth(starts.first), addMonths(startOfMonth(addDays(ends.last, -1)), 1));
}

List<(String, DateTime, DateTime)> _months(Period p) {
  final out = <(String, DateTime, DateTime)>[];
  for (var s = startOfMonth(p.start); s.isBefore(p.end); s = addMonths(s, 1)) {
    final a = s.isBefore(p.start) ? p.start : s;
    final e = addMonths(s, 1);
    out.add((DateFormat('MMM yyyy').format(s), a, e.isAfter(p.end) ? p.end : e));
  }
  return out;
}

List<(String, DateTime, DateTime)> _weeks(Period p) {
  final out = <(String, DateTime, DateTime)>[];
  for (var s = startOfWeek(p.start); s.isBefore(p.end); s = addDays(s, 7)) {
    final a = s.isBefore(p.start) ? p.start : s;
    final e = addDays(s, 7);
    out.add((DateFormat('dd-MMM-yyyy').format(s), a, e.isAfter(p.end) ? p.end : e));
  }
  return out;
}

XCell _t(String s, [XStyle st = XStyle.normal]) => XCell(s, st);
XCell _m(num? v) => XCell(v, XStyle.money);
XCell _i(num? v) => XCell(v, XStyle.integer);
XCell _p(num? pct) => XCell(pct == null ? null : pct / 100, XStyle.percent);
XCell _d(DateTime? d) => XCell(d, XStyle.date);
XCell _h(String s) => XCell(s, XStyle.header);

XSheet _summary(InsightsData data, Period range, bool everything, DateTime generatedAt) {
  final m = data.forPeriod(range);
  final sh = XSheet('Summary', columnWidths: [34, 20, 40]);
  sh.add([_t('Booking & Profit summary', XStyle.title)]);
  sh.add([
    _t(everything ? 'All data: ${DateFormat('dd MMM yyyy').format(range.start)} – ${DateFormat('dd MMM yyyy').format(addDays(range.end, -1))}' : range.label, XStyle.muted)
  ]);
  sh.add([_t('${data.property ?? 'All properties'} · generated ${DateFormat('dd MMM yyyy, h:mm a').format(generatedAt)}', XStyle.muted)]);
  sh.add([]);
  sh.add([_h('Measure'), _h('Value'), _h('Notes')]);
  void row(String label, XCell v, [String note = '']) => sh.add([_t(label), v, _t(note, XStyle.muted)]);
  row('Guest paid', _m(m.guestPaid), 'Total paid by guests');
  row('In hand', _m(m.inHand), m.pendingInHandStays > 0 ? '${m.pendingInHandStays} stay(s) still without an in-hand amount' : '');
  row('Platform cut', _m(m.cut), 'Over stays with both amounts');
  row('Platform cut %', _p(m.cutPct));
  row('Costs', _m(m.costs));
  row('Profit', _m(m.profit), 'In hand − costs');
  row('Nights booked', _i(m.nightsBooked));
  row('Nights available', _i(m.nightsAvailable), 'Calendar nights × properties − blocked nights');
  row('Occupancy', _p(m.occupancy));
  row('Stays', _i(m.stays), 'Check-ins in the period');
  row('Average length of stay (nights)', XCell(m.avgLengthOfStay, XStyle.decimal));
  row('ADR (in hand per booked night)', _m(m.adr));
  row('RevPAN (in hand ÷ nights available)', _m(m.revpan));
  row('Cancellations', _i(m.cancellations));
  row('Cancellation rate', _p(m.cancellationRate));
  row('Nights lost to cancellations', _i(m.nightsLost));
  return sh;
}

const _bookingCols = [
  'Platform', 'Booking ID', 'Guest', 'Property', 'Check-in', 'Check-out', 'Nights', 'Guests',
  'Guest paid', 'In hand', 'Cut ₹', 'Cut %', 'Costs', 'Profit', 'Status', 'Source', 'Notes',
];

XSheet _bookingsSheet(List<Booking> list) {
  final sh = XSheet('Bookings',
      columnWidths: [13, 16, 22, 18, 13, 13, 8, 8, 13, 13, 12, 8, 11, 13, 11, 9, 30], headerRow: 1, filterLastRow: list.length + 1);
  sh.add(_bookingCols.map(_h).toList());
  for (final b in list) {
    final f = Financials.ofBooking(b);
    sh.add([
      _t(b.platform), _t(b.platformBookingId), _t(b.guestName), _t(b.property), _d(b.checkIn), _d(b.checkOut),
      _i(b.nights), _i(b.guestsCount), _m(b.guestTotalPaid), _m(b.inHandAmount), _m(f.cut), _p(f.cutPct),
      _m(b.costs), _m(f.profit), _t(_cap(b.status)), _t(_cap(b.source)), _t(b.notes),
    ]);
  }
  if (list.isNotEmpty) {
    final last = list.length + 1;
    double sum(double? Function(Booking) g) => list.fold(0.0, (a, b) => a + (g(b) ?? 0));
    final totalGuest = sum((b) => b.guestTotalPaid), totalInHand = sum((b) => b.inHandAmount);
    final totalCut = sum((b) => Financials.ofBooking(b).cut), totalProfit = sum((b) => Financials.ofBooking(b).profit);
    XCell tot(int col, num v, XStyle s) => XCell(v, s, 'SUBTOTAL(9,${colName(col)}2:${colName(col)}$last)');
    sh.add([
      XCell('Total (${list.length})', XStyle.totalLabel), const XCell(null, XStyle.totalLabel), const XCell(null, XStyle.totalLabel),
      const XCell(null, XStyle.totalLabel), const XCell(null, XStyle.totalLabel), const XCell(null, XStyle.totalLabel),
      tot(6, list.fold<int>(0, (a, b) => a + b.nights), XStyle.totalInteger),
      const XCell(null, XStyle.totalLabel),
      tot(8, totalGuest, XStyle.totalMoney),
      tot(9, totalInHand, XStyle.totalMoney),
      tot(10, totalCut, XStyle.totalMoney),
      const XCell(null, XStyle.totalLabel),
      tot(12, sum((b) => b.costs), XStyle.totalMoney),
      tot(13, totalProfit, XStyle.totalMoney),
      const XCell(null, XStyle.totalLabel), const XCell(null, XStyle.totalLabel), const XCell(null, XStyle.totalLabel),
    ]);
  }
  return sh;
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

XSheet _periodSheet(String name, InsightsData data, List<(String, DateTime, DateTime)> rows, String firstCol) {
  final sh = XSheet(name, columnWidths: [16, 10, 11, 12, 14, 14, 13, 12, 14, 12], headerRow: 1, filterLastRow: rows.length + 1);
  sh.add([firstCol, 'Nights', 'Available', 'Occupancy', 'Guest paid', 'In hand', 'Cut ₹', 'Costs', 'Profit', 'ADR'].map(_h).toList());
  final all = Metrics();
  for (final r in rows) {
    final m = data.metrics(r.$2, r.$3);
    sh.add([_t(r.$1), _i(m.nightsBooked), _i(m.nightsAvailable), _p(m.occupancy), _m(m.guestPaid), _m(m.inHand), _m(m.cut), _m(m.costs), _m(m.profit), _m(m.adr)]);
    all
      ..nightsBooked += m.nightsBooked
      ..nightsAvailable += m.nightsAvailable
      ..nightsWithInHand += m.nightsWithInHand
      ..guestPaid += m.guestPaid
      ..inHand += m.inHand
      ..cutBaseGuestPaid += m.cutBaseGuestPaid
      ..cutBaseInHand += m.cutBaseInHand
      ..costs += m.costs
      ..profit += m.profit;
  }
  if (rows.isNotEmpty) {
    final last = rows.length + 1;
    XCell tot(int col, num v, XStyle s) => XCell(v, s, 'SUBTOTAL(9,${colName(col)}2:${colName(col)}$last)');
    sh.add([
      const XCell('Total', XStyle.totalLabel),
      tot(1, all.nightsBooked, XStyle.totalInteger),
      tot(2, all.nightsAvailable, XStyle.totalInteger),
      XCell((all.occupancy ?? 0) / 100, XStyle.totalPercent, 'IFERROR(B${last + 1}/C${last + 1},0)'),
      tot(4, all.guestPaid, XStyle.totalMoney),
      tot(5, all.inHand, XStyle.totalMoney),
      tot(6, all.cut, XStyle.totalMoney),
      tot(7, all.costs, XStyle.totalMoney),
      tot(8, all.profit, XStyle.totalMoney),
      XCell(all.adr ?? 0, XStyle.totalMoney),
    ]);
  }
  return sh;
}

XSheet _platformSheet(InsightsData data, Period range) {
  final stats = data.byPlatform(range);
  final sh = XSheet('By Platform', columnWidths: [14, 8, 9, 14, 14, 13, 12, 14, 14, 13], headerRow: 1, filterLastRow: stats.length + 1);
  sh.add(['Platform', 'Stays', 'Nights', 'Guest paid', 'In hand', 'Cut ₹', 'Cut %', 'Profit', 'In hand / night', 'Cancellations'].map(_h).toList());
  for (final s in stats) {
    sh.add([
      _t(s.platform), _i(s.stays), _i(s.nights), _m(s.guestPaid), _m(s.inHand), _m(s.cutBaseGuestPaid - s.cutBaseInHand),
      _p(s.commissionPct), _m(s.profit), _m(s.inHandPerNight), _i(s.cancellations),
    ]);
  }
  if (stats.isNotEmpty) {
    final last = stats.length + 1;
    XCell tot(int col, num v, XStyle s) => XCell(v, s, 'SUBTOTAL(9,${colName(col)}2:${colName(col)}$last)');
    double sum(double Function(PlatformStats) g) => stats.fold(0.0, (a, s) => a + g(s));
    sh.add([
      const XCell('Total', XStyle.totalLabel),
      tot(1, stats.fold<int>(0, (a, s) => a + s.stays), XStyle.totalInteger),
      tot(2, stats.fold<int>(0, (a, s) => a + s.nights), XStyle.totalInteger),
      tot(3, sum((s) => s.guestPaid), XStyle.totalMoney),
      tot(4, sum((s) => s.inHand), XStyle.totalMoney),
      tot(5, sum((s) => s.cutBaseGuestPaid - s.cutBaseInHand), XStyle.totalMoney),
      const XCell(null, XStyle.totalLabel),
      tot(7, sum((s) => s.profit), XStyle.totalMoney),
      const XCell(null, XStyle.totalLabel),
      tot(9, stats.fold<int>(0, (a, s) => a + s.cancellations), XStyle.totalInteger),
    ]);
  }
  return sh;
}

XSheet _blocksSheet(List<Block> blocks) {
  final sh = XSheet('Blocks', columnWidths: [18, 14, 14, 8, 16, 34], headerRow: 1, filterLastRow: blocks.length + 1);
  sh.add(['Property', 'From', 'To (last night)', 'Nights', 'Reason', 'Notes'].map(_h).toList());
  for (final b in blocks) {
    sh.add([_t(b.property), _d(b.startDate), _d(b.endDate), _i(b.nights), _t(_cap(b.reason)), _t(b.notes)]);
  }
  if (blocks.isNotEmpty) {
    sh.add([
      XCell('Total (${blocks.length})', XStyle.totalLabel), const XCell(null, XStyle.totalLabel), const XCell(null, XStyle.totalLabel),
      XCell(blocks.fold<int>(0, (a, b) => a + b.nights), XStyle.totalInteger, 'SUBTOTAL(9,D2:D${blocks.length + 1})'),
      const XCell(null, XStyle.totalLabel), const XCell(null, XStyle.totalLabel),
    ]);
  }
  return sh;
}
