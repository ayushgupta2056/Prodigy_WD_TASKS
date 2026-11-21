import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:booking_manager/core/dates.dart';
import 'package:booking_manager/core/excel_export.dart';
import 'package:booking_manager/core/insights.dart';
import 'package:booking_manager/core/models.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

double? num_(Data? d) {
  final v = d?.value;
  return switch (v) {
    IntCellValue(:final value) => value.toDouble(),
    DoubleCellValue(:final value) => value,
    FormulaCellValue() => null,
    _ => null,
  };
}

String str(Data? d) => switch (d?.value) { TextCellValue(:final value) => value.text ?? '', final v => '${v ?? ''}' };

void main() {
  final bookings = [
    Booking(id: '1', platform: 'Airbnb', platformBookingId: 'HM1', guestName: 'Rahul S', property: 'P',
        checkIn: parseIso('2026-11-02')!, checkOut: parseIso('2026-11-06')!, guestTotalPaid: 20000, inHandAmount: 17000, costs: 1000, status: 'completed', source: 'email'),
    Booking(id: '2', platform: 'MakeMyTrip', platformBookingId: 'NH1', guestName: 'Priya I', property: 'P',
        checkIn: parseIso('2026-11-10')!, checkOut: parseIso('2026-11-12')!, guestTotalPaid: 10000, inHandAmount: 7800, status: 'completed', source: 'email'),
    Booking(id: '3', platform: 'Direct', guestName: 'Anita', property: 'P',
        checkIn: parseIso('2026-11-20')!, checkOut: parseIso('2026-11-23')!, guestTotalPaid: 9000, status: 'confirmed'),
  ];
  final blocks = [Block(id: 'k', property: 'P', startDate: parseIso('2026-11-25')!, endDate: parseIso('2026-11-26')!, reason: 'maintenance')];
  final data = InsightsData(bookings: bookings, blocks: blocks, properties: ['P']);
  final period = Period.containing(PeriodKind.month, parseIso('2026-11-01')!);

  test('workbook opens with the six sheets and correct totals', () {
    final bytes = buildExport(data: data, period: period, generatedAt: DateTime(2026, 11, 30));
    final x = Excel.decodeBytes(bytes);
    expect(x.tables.keys.toList(), ['Summary', 'Bookings', 'Monthly', 'Weekly', 'By Platform', 'Blocks']);

    final bk = x.tables['Bookings']!;
    expect(str(bk.rows[0][0]), 'Platform');
    expect(bk.maxRows, 5); // header + 3 + total
    expect(str(bk.rows[1][2]), 'Rahul S');
    expect(num_(bk.rows[1][10]), 3000); // cut
    expect(num_(bk.rows[1][11]), closeTo(0.15, 1e-9)); // cut % stored as a fraction
    expect(num_(bk.rows[1][13]), 16000); // profit
    final totals = bk.rows[4];
    expect(str(totals[0]), 'Total (3)');

    final summary = x.tables['Summary']!;
    double summaryValue(String label) => num_(summary.rows.firstWhere((r) => r.isNotEmpty && str(r[0]) == label)[1])!;
    expect(summaryValue('Guest paid'), 39000);
    expect(summaryValue('In hand'), 24800);
    expect(summaryValue('Profit'), 23800);
    expect(summaryValue('Nights booked'), 9);
    expect(summaryValue('Nights available'), 28);

    final monthly = x.tables['Monthly']!;
    expect(monthly.maxRows, 3); // header, Nov, total
    expect(str(monthly.rows[1][0]), 'Nov 2026');
    expect(num_(monthly.rows[1][5]), 24800);

    final plat = x.tables['By Platform']!;
    expect(plat.rows.skip(1).map((r) => str(r[0])).toList(), ['Airbnb', 'MakeMyTrip', 'Direct', 'Total']);

    final bl = x.tables['Blocks']!;
    expect(str(bl.rows[1][4]), 'Maintenance');
    expect(num_(bl.rows[1][3]), 2);
  });

  test('raw xml has frozen header, autofilter, Indian ₹ format and totals formulas', () {
    final bytes = buildExport(data: data, period: null);
    final zip = ZipDecoder().decodeBytes(bytes);
    String file(String name) => utf8.decode(zip.findFile(name)!.content as List<int>);
    final bookingsXml = file('xl/worksheets/sheet2.xml');
    expect(bookingsXml, contains('<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'));
    expect(bookingsXml, contains('<autoFilter ref="A1:Q4"/>'));
    expect(bookingsXml, contains('<f>SUBTOTAL(9,I2:I4)</f><v>39000.0</v>'));
    final styles = file('xl/styles.xml');
    expect(styles, contains('[&gt;=100000]&quot;₹&quot;##\\,##\\,##0'));
    expect(styles, contains(r'formatCode="dd\-mmm\-yyyy"'));
    expect(file('xl/workbook.xml'), contains('_xlnm._FilterDatabase'));
  });
}
