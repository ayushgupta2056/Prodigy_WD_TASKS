import 'package:booking_manager/core/dates.dart';
import 'package:booking_manager/core/insights.dart';
import 'package:booking_manager/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

Booking bk(String id, String ci, String co, {String platform = 'Airbnb', double? paid, double? inHand, double costs = 0, String status = 'completed', String created = ''}) =>
    Booking(id: id, platform: platform, checkIn: parseIso(ci)!, checkOut: parseIso(co)!, guestTotalPaid: paid, inHandAmount: inHand, costs: costs, status: status, createdAt: created);

InsightsData data(List<Booking> b, {List<Block> blocks = const [], List<String> props = const ['P']}) =>
    InsightsData(bookings: b, blocks: blocks, properties: props);

void main() {
  final nov = Period.containing(PeriodKind.month, parseIso('2026-11-12')!);

  test('periods: containing, shift, labels, last year', () {
    expect(toIso(nov.start), '2026-11-01');
    expect(toIso(nov.end), '2026-12-01');
    expect(nov.label, 'November 2026');
    expect(toIso(nov.previous.start), '2026-10-01');
    expect(toIso(nov.sameLastYear!.start), '2025-11-01');
    final w = Period.containing(PeriodKind.week, parseIso('2026-11-12')!); // Thursday
    expect(toIso(w.start), '2026-11-09'); // Monday
    expect(w.days, 7);
    final q = Period.containing(PeriodKind.quarter, parseIso('2026-11-12')!);
    expect(q.label, 'Q4 2026');
    expect(toIso(q.shift(1).start), '2027-01-01');
    expect(Period.containing(PeriodKind.year, parseIso('2026-11-12')!).sameLastYear!.label, '2025');
    expect(Period.containing(PeriodKind.week, parseIso('2026-11-12')!).sameLastYear, isNull);
    final c = Period.custom(parseIso('2026-11-01')!, parseIso('2026-11-10')!);
    expect(c.days, 10);
    expect(toIso(c.previous.start), '2026-10-22');
  });

  test('occupancy, ADR, RevPAN, cut, profit for a month', () {
    final m = data([
      bk('a', '2026-11-02', '2026-11-06', paid: 20000, inHand: 17000, costs: 1000), // 4 nights
      bk('b', '2026-11-10', '2026-11-12', platform: 'Agoda', paid: 10000, inHand: 8000), // 2 nights
      bk('c', '2026-11-20', '2026-11-24', paid: 12000, status: 'confirmed'), // 4 nights, no in-hand yet
    ]).forPeriod(nov);
    expect(m.nightsBooked, 10);
    expect(m.nightsAvailable, 30);
    expect(m.occupancy, closeTo(33.33, 0.01));
    expect(m.guestPaid, 42000);
    expect(m.inHand, 25000);
    expect(m.cut, 5000); // only over stays with both amounts
    expect(m.cutPct, closeTo(16.67, 0.01));
    expect(m.costs, 1000);
    expect(m.profit, 24000);
    expect(m.adr, closeTo(4166.67, 0.01)); // 25000 / 6 nights with in-hand
    expect(m.revpan, closeTo(833.33, 0.01));
    expect(m.stays, 3);
    expect(m.avgLengthOfStay, closeTo(3.33, 0.01));
    expect(m.pendingInHandStays, 1);
  });

  test('stays spanning months are split pro rata by night', () {
    final d = data([bk('a', '2026-10-30', '2026-11-03', paid: 8000, inHand: 6000)]); // 2 Oct + 2 Nov nights
    final m = d.forPeriod(nov);
    expect(m.nightsBooked, 2);
    expect(m.inHand, 3000);
    expect(m.guestPaid, 4000);
    expect(m.stays, 0); // check-in was in October
    expect(d.forPeriod(nov.previous).stays, 1);
  });

  test('blocks reduce available nights; multiple properties add capacity', () {
    final blocks = [Block(id: 'k', property: 'P', startDate: parseIso('2026-11-10')!, endDate: parseIso('2026-11-14')!)];
    expect(data([], blocks: blocks).forPeriod(nov).nightsAvailable, 25);
    expect(data([], props: ['P', 'Q']).forPeriod(nov).nightsAvailable, 60);
  });

  test('cancellations: count, rate, nights lost; excluded from money', () {
    final m = data([
      bk('a', '2026-11-02', '2026-11-05', paid: 9000, inHand: 8000),
      bk('x', '2026-11-10', '2026-11-14', paid: 15000, status: 'cancelled'),
    ]).forPeriod(nov);
    expect(m.cancellations, 1);
    expect(m.nightsLost, 4);
    expect(m.cancellationRate, 50);
    expect(m.guestPaid, 9000);
    expect(m.nightsBooked, 3);
  });

  test('period-over-period change', () {
    expect(pctChange(118, 100), closeTo(18, 0.001));
    expect(pctChange(80, 100), closeTo(-20, 0.001));
    expect(pctChange(10, 0), isNull);
    expect(pctChange(null, 5), isNull);
  });

  test('platform comparison: in-hand per night and effective commission', () {
    final stats = data([
      bk('a', '2026-11-02', '2026-11-04', platform: 'Airbnb', paid: 10000, inHand: 8500),
      bk('b', '2026-11-05', '2026-11-07', platform: 'Airbnb', paid: 10000, inHand: 8500),
      bk('c', '2026-11-08', '2026-11-10', platform: 'MakeMyTrip', paid: 10000, inHand: 7800),
    ]).byPlatform(nov);
    final air = stats.firstWhere((s) => s.platform == 'Airbnb');
    final mmt = stats.firstWhere((s) => s.platform == 'MakeMyTrip');
    expect(air.inHandPerNight, 4250);
    expect(air.commissionPct, 15);
    expect(mmt.commissionPct, closeTo(22, 0.001));
    expect(stats.first.platform, 'Airbnb'); // ranked by in-hand
  });

  test('day of week: nights and in-hand per night', () {
    // 2026-11-13 is a Friday; two nights: Fri + Sat at 5000/night.
    final wd = data([bk('a', '2026-11-13', '2026-11-15', inHand: 10000, paid: 11000)]).byWeekday(nov);
    expect(wd[4].nights, 1);
    expect(wd[5].nights, 1);
    expect(wd[5].perNight, 5000);
    expect(wd[0].nights, 0);
    expect(wd[0].available, 5); // five Mondays in Nov 2026
  });

  test('lead time from booking date to check-in', () {
    final lt = data([
      bk('a', '2026-11-20', '2026-11-22', created: '2026-11-01T10:00:00+05:30'),
      bk('b', '2026-11-25', '2026-11-26', created: '2026-11-24T10:00:00+05:30'),
    ]).leadTimes(nov);
    expect(lt['Airbnb']!.days, [19, 1]);
    expect(lt['Airbnb']!.average, 10);
    expect(lt['Airbnb']!.histogram, [1, 1, 0, 0]);
  });

  test('forward look: booked nights, expected revenue, gaps', () {
    final t = parseIso('2026-11-12')!;
    final f = data([
      bk('a', '2026-11-12', '2026-11-15', paid: 9000, status: 'confirmed'),
      bk('b', '2026-11-18', '2026-11-20', paid: 6000, status: 'confirmed'),
    ]).forward(t, 14);
    expect(f.nightsBooked, 5);
    expect(f.expectedGuestPaid, 15000);
    expect(f.gaps.map((g) => '${toIso(g.start)}:${g.nights}').toList(), ['2026-11-15:3', '2026-11-20:6']);
  });

  test('overlaps: double bookings and booking-vs-block on the same property only', () {
    final o = findOverlaps([
      bk('a', '2026-11-10', '2026-11-14', status: 'confirmed'),
      bk('b', '2026-11-13', '2026-11-15', status: 'confirmed'),
      bk('c', '2026-11-14', '2026-11-16', status: 'confirmed'), // touches a at check-out: fine
      bk('x', '2026-11-10', '2026-11-12', status: 'cancelled'),
      Booking(id: 'q', property: 'Q', checkIn: parseIso('2026-11-10')!, checkOut: parseIso('2026-11-14')!),
    ], [
      Block(id: 'k', property: 'P', startDate: parseIso('2026-11-15')!, endDate: parseIso('2026-11-15')!),
    ], properties: ['P', 'Q'], defaultProperty: 'P');
    final pairs = o.map((x) => '${x.aId}-${x.bId}').toSet();
    expect(pairs, {'a-b', 'b-c', 'c-k'});
  });

  test('auto insights only appear with enough data and use real numbers', () {
    expect(generateInsights(data([]), nov, parseIso('2026-11-30')!).where((c) => c.kind != 'gaps'), isEmpty);

    final cards = generateInsights(
        data([
          bk('a', '2026-11-02', '2026-11-04', platform: 'Airbnb', paid: 10000, inHand: 8500),
          bk('b', '2026-11-05', '2026-11-07', platform: 'Airbnb', paid: 10000, inHand: 8500),
          bk('c', '2026-11-08', '2026-11-10', platform: 'MakeMyTrip', paid: 10000, inHand: 7800),
          bk('d', '2026-11-16', '2026-11-18', platform: 'MakeMyTrip', paid: 10000, inHand: 7800),
          bk('e', '2026-11-20', '2026-11-22', paid: 9000), // completed, no in-hand
        ]),
        nov,
        parseIso('2026-11-30')!);
    final byKind = {for (final c in cards) c.kind: c.text};
    expect(byKind['commission'], 'MakeMyTrip took 22% of guest payments in November vs 15% on Airbnb.');
    expect(byKind['pending'], '1 completed stay still has no in-hand amount entered.');
    expect(cards.first.kind, 'pending'); // most actionable first
  });
}
