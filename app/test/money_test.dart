import 'package:booking_manager/core/dates.dart';
import 'package:booking_manager/core/format.dart';
import 'package:booking_manager/core/models.dart';
import 'package:booking_manager/core/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Booking b({double? paid, double? inHand, double costs = 0, String ci = '2026-11-12', String co = '2026-11-16'}) =>
      Booking(id: 'x', checkIn: parseIso(ci)!, checkOut: parseIso(co)!, guestTotalPaid: paid, inHandAmount: inHand, costs: costs);

  test('nights', () {
    expect(b().nights, 4);
    expect(b(ci: '2026-12-30', co: '2027-01-02').nights, 3);
    expect(b(ci: '2028-02-28', co: '2028-03-01').nights, 2);
    expect(b(ci: '2026-11-16', co: '2026-11-12').nights, 0);
  });

  test('example from the brief matches the backend', () {
    final f = Financials.ofBooking(b(paid: 18400, inHand: 15640, costs: 1200));
    expect(f.cut, 2760);
    expect(f.cutPct, 15);
    expect(f.profit, 14440);
    expect(f.perNight, 3910);
    expect(f.pending, isFalse);
  });

  test('pending in-hand: nothing is guessed', () {
    final f = Financials.ofBooking(b(paid: 9000));
    expect(f.pending, isTrue);
    expect(f.cut, isNull);
    expect(f.profit, isNull);
    expect(f.perNight, isNull);
  });

  test('rounding and zero guest paid', () {
    final f = Financials.ofBooking(b(paid: 12450, inHand: 10000, ci: '2026-11-01', co: '2026-11-04'));
    expect(f.cutPct, 19.68);
    expect(f.perNight, 3333.33);
    expect(Financials.ofBooking(b(paid: 0, inHand: 0)).cutPct, isNull);
  });

  test('Indian rupee formatting', () {
    expect(inr(123456), '₹1,23,456');
    expect(inr(12345678), '₹1,23,45,678');
    expect(inr(999), '₹999');
    expect(inr(1000), '₹1,000');
    expect(inr(-2500), '−₹2,500');
    expect(inr(12450.5, decimals: 2), '₹12,450.50');
    expect(inr(null), '—');
    expect(inrCompact(142300), '₹1.4L');
    expect(inrCompact(25000000), '₹2.5Cr');
    expect(parseAmountInput('₹ 12,450'), 12450);
    expect(parseAmountInput('Rs. 900'), 900);
    expect(parseAmountInput(''), isNull);
  });

  test('dates', () {
    expect(fmtDate(parseIso('2026-11-12')), '12 Nov 2026');
    expect(fmtRange(parseIso('2026-11-12')!, parseIso('2026-11-16')!), '12–16 Nov');
    expect(fmtRange(parseIso('2026-11-28')!, parseIso('2026-12-02')!), '28 Nov – 2 Dec');
    expect(shortName('Rahul Sharma'), 'Rahul S.');
  });
}
