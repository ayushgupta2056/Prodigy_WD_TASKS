import 'dart:math';

import '../core/dates.dart';
import '../core/models.dart';

/// Believable sample data for demo mode. All names and IDs are made up and
/// the commission rates are illustrative only.
Snapshot buildDemoSnapshot(DateTime now) {
  final rnd = Random(7);
  final t = today(now);
  const property = 'Cedar Cottage';
  final start = DateTime.utc(t.year - 1, t.month, 1);
  final horizon = addDays(t, 100);

  const names = [
    'Rahul Sharma', 'Priya Iyer', 'Ananya Gupta', 'Vikram Rao', 'Sneha Kulkarni', 'Arjun Mehta', 'Kavya Nair',
    'Rohan Desai', 'Meera Pillai', 'Aditya Singh', 'Ishita Bose', 'Karan Malhotra', 'Neha Joshi', 'Siddharth Menon',
    'Pooja Reddy', 'Aman Verma', 'Tanvi Shah', 'Nikhil Chopra', 'Divya Krishnan', 'Harsh Agarwal', 'Ritu Saxena',
    'Emma Clarke', 'Lucas Martin', 'Sara Haddad', 'Daniel Brooks', 'Aarav Kapoor', 'Zoya Khan', 'Kabir Bhatia',
  ];
  const mix = [
    ('Airbnb', 0.34, 0.155), ('MakeMyTrip', 0.17, 0.22), ('Goibibo', 0.11, 0.21),
    ('Agoda', 0.10, 0.18), ('Booking.com', 0.16, 0.17), ('Direct', 0.12, 0.0),
  ];
  String pickPlatform() {
    var r = rnd.nextDouble();
    for (final m in mix) {
      if ((r -= m.$2) <= 0) return m.$1;
    }
    return 'Airbnb';
  }

  double rate(String p) => mix.firstWhere((m) => m.$1 == p).$3;
  String bookingId(String p) {
    String digits(int n) => List.generate(n, (_) => rnd.nextInt(10)).join();
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    String alnum(int n) => List.generate(n, (_) => rnd.nextBool() ? letters[rnd.nextInt(letters.length)] : '${rnd.nextInt(10)}').join();
    return switch (p) {
      'Airbnb' => 'HM${alnum(8)}',
      'MakeMyTrip' => 'NH7${digits(9)}',
      'Goibibo' => 'GO${digits(10)}',
      'Agoda' => digits(9),
      'Booking.com' => digits(10),
      _ => '',
    };
  }

  double nightly(DateTime n) {
    var r = 3600.0;
    if (n.weekday == DateTime.friday || n.weekday == DateTime.saturday) r += 1300;
    if ([12, 1, 5, 6, 10].contains(n.month)) r *= 1.25;
    return r;
  }

  final bookings = <Booking>[];
  var d = addDays(start, rnd.nextInt(3));
  var i = 0;
  var pendingLeft = 3;
  while (d.isBefore(horizon)) {
    final busy = [12, 1, 5, 6, 10].contains(d.month);
    final len = 1 + rnd.nextInt(busy ? 5 : 4) + (d.weekday >= 5 ? 1 : 0);
    final ci = d, co = addDays(d, len);
    final p = pickPlatform();
    final base = eachNight(ci, co).fold<double>(0, (a, n) => a + nightly(n));
    final guestPaid = ((base * (1 + rate(p) * 0.6)) / 10).round() * 10.0;
    final inHand = ((guestPaid * (1 - rate(p))) / 10).round() * 10.0;
    final cancelled = rnd.nextDouble() < 0.07;
    final done = !co.isAfter(t);
    var hasInHand = done;
    if (done && co.isAfter(addDays(t, -25)) && pendingLeft > 0) {
      hasInHand = false;
      pendingLeft--;
    }
    final lead = switch (p) {
      'Airbnb' => 10 + rnd.nextInt(45),
      'Booking.com' => 5 + rnd.nextInt(60),
      'Direct' => 3 + rnd.nextInt(20),
      _ => 1 + rnd.nextInt(21),
    };
    final created = addDays(ci, -lead);
    bookings.add(Booking(
      id: 'demo-${i++}',
      property: property,
      platform: p,
      platformBookingId: bookingId(p),
      guestName: names[rnd.nextInt(names.length)],
      guestsCount: 1 + rnd.nextInt(4),
      checkIn: ci,
      checkOut: co,
      guestTotalPaid: guestPaid,
      inHandAmount: cancelled ? null : (hasInHand ? inHand : null),
      costs: cancelled || !done ? 0 : 450 + 150.0 * len,
      status: cancelled ? 'cancelled' : (done ? 'completed' : 'confirmed'),
      source: p == 'Direct' ? 'manual' : 'email',
      createdAt: '${toIso(created)}T10:00:00+05:30',
      updatedAt: '${toIso(created)}T10:00:00+05:30',
      notes: p == 'Direct' && rnd.nextBool() ? 'Paid by UPI' : '',
    ));
    // Busy months fill up; quieter months leave midweek gaps.
    final gap = cancelled ? 0 : (busy ? rnd.nextInt(2) : rnd.nextInt(4));
    d = addDays(co, gap);
  }

  // Leave a visible run of empty nights in the next fortnight.
  bookings.removeWhere((b) => b.checkIn.isAfter(addDays(t, 3)) && b.checkIn.isBefore(addDays(t, 9)));

  // One double booking, to show the alarm.
  final future = bookings.where((b) => b.checkIn.isAfter(addDays(t, 16)) && b.isActive && b.nights >= 2).toList();
  if (future.isNotEmpty) {
    final f = future.first;
    bookings.add(Booking(
      id: 'demo-overlap',
      property: property,
      platform: f.platform == 'Booking.com' ? 'Agoda' : 'Booking.com',
      platformBookingId: bookingId('Booking.com'),
      guestName: 'Daniel Brooks',
      guestsCount: 2,
      checkIn: addDays(f.checkOut, -1),
      checkOut: f.checkOut,
      guestTotalPaid: 5200,
      status: 'confirmed',
      source: 'email',
      createdAt: '${toIso(addDays(t, -1))}T09:12:00+05:30',
    ));
  }

  // Mark one emailed amount as hand-corrected.
  final ix = bookings.indexWhere((b) => b.isEmail && b.status == 'completed');
  if (ix >= 0) bookings[ix] = bookings[ix].copyWith(editedFields: ['guest_total_paid']);

  final blocks = [
    Block(id: 'demo-block-1', property: property, startDate: addDays(t, 44), endDate: addDays(t, 47), reason: 'personal use', notes: 'Family visiting'),
    Block(id: 'demo-block-2', property: property, startDate: DateTime.utc(t.year, t.month - 4, 9), endDate: DateTime.utc(t.year, t.month - 4, 11), reason: 'maintenance', notes: 'Roof repair'),
  ];
  // Blocks win over demo bookings that happen to collide with them (except the deliberate overlap).
  bookings.removeWhere((b) => b.id != 'demo-overlap' && blocks.any((k) => overlapNights(b.checkIn, b.checkOut, k.startDate, k.endExclusive) > 0));

  return Snapshot(
    bookings: bookings,
    blocks: blocks,
    properties: const [property],
    defaultProperty: property,
    unparsed: [
      UnparsedEmail(
        emailMessageId: 'demo-mail-1',
        platform: 'Goibibo',
        subject: 'Booking Confirmed – Reservation for ${fmtShort(addDays(t, 21))}',
        from: 'noreply@goibibo.com',
        receivedAt: now.subtract(const Duration(hours: 5)),
        error: 'Goibibo parser not built yet: waiting for sample emails',
        gmailUrl: 'https://mail.google.com/mail/u/0/#inbox',
      ),
      UnparsedEmail(
        emailMessageId: 'demo-mail-2',
        platform: 'Agoda',
        subject: 'Agoda: Booking modification for your property',
        from: 'no-reply@agoda.com',
        receivedAt: now.subtract(const Duration(days: 2, hours: 3)),
        error: 'Incomplete parse: missing check_out',
        gmailUrl: 'https://mail.google.com/mail/u/0/#inbox',
      ),
    ],
  );
}

String fmtShort(DateTime d) => '${d.day}/${d.month}/${d.year}';
