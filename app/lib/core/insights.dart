import 'dart:math' as math;

import 'package:intl/intl.dart';

import 'dates.dart';
import 'format.dart';
import 'models.dart';

// ---------------------------------------------------------------------------
// Periods
// ---------------------------------------------------------------------------

enum PeriodKind { week, month, quarter, year, custom }

class Period {
  final PeriodKind kind;
  final DateTime start;

  /// Exclusive.
  final DateTime end;

  const Period(this.kind, this.start, this.end);

  factory Period.containing(PeriodKind kind, DateTime d) {
    switch (kind) {
      case PeriodKind.week:
        final s = startOfWeek(d);
        return Period(kind, s, addDays(s, 7));
      case PeriodKind.month:
        final s = startOfMonth(d);
        return Period(kind, s, addMonths(s, 1));
      case PeriodKind.quarter:
        final s = startOfQuarter(d);
        return Period(kind, s, addMonths(s, 3));
      case PeriodKind.year:
      case PeriodKind.custom:
        final s = startOfYear(d);
        return Period(PeriodKind.year, s, DateTime.utc(s.year + 1, 1, 1));
    }
  }

  factory Period.custom(DateTime start, DateTime lastDayInclusive) =>
      Period(PeriodKind.custom, start, addDays(lastDayInclusive, 1));

  int get days => daysBetween(start, end);
  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  /// Move by [n] periods of the same kind (custom ranges move by their length).
  Period shift(int n) {
    switch (kind) {
      case PeriodKind.week:
        return Period(kind, addDays(start, 7 * n), addDays(end, 7 * n));
      case PeriodKind.month:
        return Period(kind, addMonths(start, n), addMonths(start, n + 1));
      case PeriodKind.quarter:
        return Period(kind, addMonths(start, 3 * n), addMonths(start, 3 * n + 3));
      case PeriodKind.year:
        return Period(kind, DateTime.utc(start.year + n, 1, 1), DateTime.utc(start.year + n + 1, 1, 1));
      case PeriodKind.custom:
        return Period(kind, addDays(start, days * n), addDays(end, days * n));
    }
  }

  Period get previous => shift(-1);

  /// Same period a year earlier: only for month and year, as in the brief.
  Period? get sameLastYear {
    if (kind == PeriodKind.month) return shift(-12);
    if (kind == PeriodKind.year) return shift(-1);
    return null;
  }

  String get label {
    final last = addDays(end, -1);
    switch (kind) {
      case PeriodKind.week:
        return fmtRange(start, last);
      case PeriodKind.month:
        return DateFormat('MMMM yyyy').format(start);
      case PeriodKind.quarter:
        return 'Q${(start.month - 1) ~/ 3 + 1} ${start.year}';
      case PeriodKind.year:
        return '${start.year}';
      case PeriodKind.custom:
        return fmtRange(start, last);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Period && other.kind == kind && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(kind, start, end);
}

/// % change from [prev] to [cur]; null when there is nothing to compare with.
double? pctChange(num? cur, num? prev) {
  if (cur == null || prev == null || prev == 0) return null;
  return (cur - prev) / prev.abs() * 100;
}

// ---------------------------------------------------------------------------
// Metrics
// ---------------------------------------------------------------------------

/// Money is attributed to a period pro rata by night: a 4-night stay with 2
/// nights in October puts half its amounts in October.
class Metrics {
  double guestPaid = 0;
  double inHand = 0;
  double costs = 0;
  double profit = 0;

  /// Guest paid and in-hand over the stays that have BOTH, so the platform cut
  /// is never distorted by stays still waiting for their in-hand amount.
  double cutBaseGuestPaid = 0;
  double cutBaseInHand = 0;

  int nightsBooked = 0;
  int nightsWithInHand = 0;
  int nightsAvailable = 0;
  int stays = 0;
  int staysNights = 0;
  int pendingInHandStays = 0;
  int cancellations = 0;
  int nightsLost = 0;

  double get cut => cutBaseGuestPaid - cutBaseInHand;
  double? get cutPct => cutBaseGuestPaid > 0 ? cut / cutBaseGuestPaid * 100 : null;
  double? get occupancy => nightsAvailable > 0 ? nightsBooked / nightsAvailable * 100 : null;
  double? get avgLengthOfStay => stays > 0 ? staysNights / stays : null;

  /// Average in-hand per booked night (nights whose in-hand is known).
  double? get adr => nightsWithInHand > 0 ? inHand / nightsWithInHand : null;

  /// In-hand ÷ nights available.
  double? get revpan => nightsAvailable > 0 ? inHand / nightsAvailable : null;
  double? get cancellationRate => (stays + cancellations) > 0 ? cancellations / (stays + cancellations) * 100 : null;
  bool get hasData => nightsBooked > 0 || cancellations > 0;
}

class InsightsData {
  final List<Booking> bookings;
  final List<Block> blocks;
  final List<String> properties;
  final String defaultProperty;

  /// null = all properties.
  final String? property;

  InsightsData({
    required List<Booking> bookings,
    required List<Block> blocks,
    required List<String> properties,
    this.defaultProperty = '',
    this.property,
  })  : properties = properties.isEmpty ? const ['My property'] : properties,
        bookings = bookings.where((b) => property == null || _prop(b.property, defaultProperty, properties) == property).toList(),
        blocks = blocks.where((b) => property == null || _prop(b.property, defaultProperty, properties) == property).toList();

  static String _prop(String p, String def, List<String> props) =>
      p.isNotEmpty ? p : (def.isNotEmpty ? def : (props.isNotEmpty ? props.first : ''));

  int get propertyCount => property == null ? properties.length : 1;
  Iterable<Booking> get active => bookings.where((b) => b.isActive && b.nights > 0);

  /// Blocked nights inside [start,end), counted once per property per night.
  int blockedNights(DateTime start, DateTime end) {
    final seen = <String>{};
    for (final b in blocks) {
      final p = _prop(b.property, defaultProperty, properties);
      for (final n in eachNight(b.startDate.isBefore(start) ? start : b.startDate, b.endExclusive.isAfter(end) ? end : b.endExclusive)) {
        seen.add('$p|${toIso(n)}');
      }
    }
    return seen.length;
  }

  Metrics metrics(DateTime start, DateTime end) {
    final m = Metrics();
    m.nightsAvailable = math.max(0, daysBetween(start, end) * propertyCount - blockedNights(start, end));
    for (final b in bookings) {
      if (b.nights <= 0) continue;
      final inPeriodCheckIn = !b.checkIn.isBefore(start) && b.checkIn.isBefore(end);
      if (b.isCancelled) {
        if (inPeriodCheckIn) {
          m.cancellations++;
          m.nightsLost += b.nights;
        }
        continue;
      }
      if (!b.isActive) continue;
      if (inPeriodCheckIn) {
        m.stays++;
        m.staysNights += b.nights;
        if (b.pendingInHand) m.pendingInHandStays++;
      }
      final n = overlapNights(b.checkIn, b.checkOut, start, end);
      if (n == 0) continue;
      final f = n / b.nights;
      m.nightsBooked += n;
      m.guestPaid += (b.guestTotalPaid ?? 0) * f;
      m.costs += b.costs * f;
      if (b.inHandAmount != null) {
        m.inHand += b.inHandAmount! * f;
        m.profit += (b.inHandAmount! - b.costs) * f;
        m.nightsWithInHand += n;
        if (b.guestTotalPaid != null) {
          m.cutBaseGuestPaid += b.guestTotalPaid! * f;
          m.cutBaseInHand += b.inHandAmount! * f;
        }
      }
    }
    return m;
  }

  Metrics forPeriod(Period p) => metrics(p.start, p.end);

  // ---- Buckets for charts ------------------------------------------------

  List<Bucket> buckets(Period p) {
    final out = <Bucket>[];
    final granularity = switch (p.kind) {
      PeriodKind.week => _G.day,
      PeriodKind.month || PeriodKind.quarter => _G.week,
      PeriodKind.year => _G.month,
      PeriodKind.custom => p.days <= 31 ? _G.day : (p.days <= 120 ? _G.week : _G.month),
    };
    var s = p.start;
    while (s.isBefore(p.end)) {
      var e = switch (granularity) {
        _G.day => addDays(s, 1),
        _G.week => addDays(startOfWeek(s), 7),
        _G.month => addMonths(startOfMonth(s), 1),
      };
      if (e.isAfter(p.end)) e = p.end;
      final label = switch (granularity) {
        _G.day => '${s.day}',
        _G.week => fmtDayMonth(s),
        _G.month => DateFormat('MMM').format(s),
      };
      out.add(Bucket(label, s, e, metrics(s, e)));
      s = e;
    }
    return out;
  }

  // ---- Platform mix & comparison ----------------------------------------

  List<PlatformStats> byPlatform(Period p) {
    final map = <String, PlatformStats>{};
    for (final b in bookings) {
      final st = map.putIfAbsent(b.platform, () => PlatformStats(b.platform));
      if (b.isCancelled) {
        if (p.contains(b.checkIn)) st.cancellations++;
        continue;
      }
      if (!b.isActive || b.nights == 0) continue;
      final n = overlapNights(b.checkIn, b.checkOut, p.start, p.end);
      if (n == 0) continue;
      final f = n / b.nights;
      if (p.contains(b.checkIn)) st.stays++;
      st.nights += n;
      st.guestPaid += (b.guestTotalPaid ?? 0) * f;
      if (b.inHandAmount != null) {
        st.inHand += b.inHandAmount! * f;
        st.profit += (b.inHandAmount! - b.costs) * f;
        st.nightsWithInHand += n;
        if (b.guestTotalPaid != null) {
          st.cutBaseGuestPaid += b.guestTotalPaid! * f;
          st.cutBaseInHand += b.inHandAmount! * f;
          st.staysWithBoth++;
        }
      }
    }
    final list = map.values.where((s) => s.nights > 0 || s.cancellations > 0).toList()
      ..sort((a, b) => b.inHand.compareTo(a.inHand) != 0 ? b.inHand.compareTo(a.inHand) : b.nights.compareTo(a.nights));
    return list;
  }

  // ---- Day of week --------------------------------------------------------

  /// Index 0 = Monday night ... 6 = Sunday night.
  List<WeekdayStats> byWeekday(Period p) {
    final out = List.generate(7, (i) => WeekdayStats(i));
    for (final b in active) {
      final perNight = b.inHandAmount != null && b.nights > 0 ? b.inHandAmount! / b.nights : null;
      final s = b.checkIn.isBefore(p.start) ? p.start : b.checkIn;
      final e = b.checkOut.isAfter(p.end) ? p.end : b.checkOut;
      for (final n in eachNight(s, e)) {
        final w = out[n.weekday - 1];
        w.nights++;
        if (perNight != null) {
          w.inHand += perNight;
          w.nightsWithInHand++;
        }
      }
    }
    // Available nights per weekday, for an occupancy rate.
    for (final n in eachNight(p.start, p.end)) {
      out[n.weekday - 1].available += propertyCount;
    }
    return out;
  }

  // ---- Lead time ------------------------------------------------------------

  /// Days between when a booking was made and check-in, per platform, for
  /// stays checking in during [p]. Uses the booking's created date, which for
  /// emailed bookings is when the confirmation arrived.
  Map<String, LeadTimeStats> leadTimes(Period p) {
    final out = <String, LeadTimeStats>{};
    for (final b in bookings) {
      if (!p.contains(b.checkIn) || b.bookedOn == null) continue;
      final d = daysBetween(b.bookedOn!, b.checkIn);
      if (d < 0) continue;
      out.putIfAbsent(b.platform, () => LeadTimeStats(b.platform)).days.add(d);
    }
    return out;
  }

  // ---- Heatmap ---------------------------------------------------------------

  /// For each day of [year]: share of properties booked that night (0..1), or
  /// -1 if every property is blocked.
  Map<DateTime, double> yearHeatmap(int year) {
    final start = DateTime.utc(year, 1, 1), end = DateTime.utc(year + 1, 1, 1);
    final booked = <DateTime, Set<String>>{};
    for (final b in active) {
      final p = _prop(b.property, defaultProperty, properties);
      for (final n in eachNight(b.checkIn.isBefore(start) ? start : b.checkIn, b.checkOut.isAfter(end) ? end : b.checkOut)) {
        booked.putIfAbsent(n, () => {}).add(p);
      }
    }
    final blocked = <DateTime, Set<String>>{};
    for (final b in blocks) {
      final p = _prop(b.property, defaultProperty, properties);
      for (final n in eachNight(b.startDate.isBefore(start) ? start : b.startDate, b.endExclusive.isAfter(end) ? end : b.endExclusive)) {
        blocked.putIfAbsent(n, () => {}).add(p);
      }
    }
    final out = <DateTime, double>{};
    for (final n in eachNight(start, end)) {
      final bk = booked[n]?.length ?? 0;
      final bl = blocked[n]?.length ?? 0;
      out[n] = (bk == 0 && bl >= propertyCount) ? -1 : bk / propertyCount;
    }
    return out;
  }

  // ---- Forward look ------------------------------------------------------------

  ForwardLook forward(DateTime fromDay, int days) {
    final end = addDays(fromDay, days);
    final m = metrics(fromDay, end);
    final gaps = <Gap>[];
    final props = property == null ? properties : [property!];
    for (final p in props) {
      final taken = <DateTime>{};
      for (final b in active.where((b) => _prop(b.property, defaultProperty, properties) == p)) {
        taken.addAll(eachNight(b.checkIn, b.checkOut));
      }
      for (final b in blocks.where((b) => _prop(b.property, defaultProperty, properties) == p)) {
        taken.addAll(eachNight(b.startDate, b.endExclusive));
      }
      DateTime? runStart;
      for (final n in eachNight(fromDay, end)) {
        final free = !taken.contains(n);
        if (free && runStart == null) runStart = n;
        if (!free && runStart != null) {
          gaps.add(Gap(p, runStart, n));
          runStart = null;
        }
      }
      if (runStart != null) gaps.add(Gap(p, runStart, end));
    }
    gaps.sort((a, b) => a.start.compareTo(b.start));
    return ForwardLook(days, m.nightsBooked, m.nightsAvailable, m.guestPaid, gaps);
  }
}

enum _G { day, week, month }

class Bucket {
  final String label;
  final DateTime start;
  final DateTime end;
  final Metrics m;
  Bucket(this.label, this.start, this.end, this.m);
}

class PlatformStats {
  final String platform;
  int stays = 0;
  int nights = 0;
  int nightsWithInHand = 0;
  int cancellations = 0;
  int staysWithBoth = 0;
  double guestPaid = 0;
  double inHand = 0;
  double profit = 0;
  double cutBaseGuestPaid = 0;
  double cutBaseInHand = 0;
  PlatformStats(this.platform);

  double? get inHandPerNight => nightsWithInHand > 0 ? inHand / nightsWithInHand : null;
  double? get commissionPct => cutBaseGuestPaid > 0 ? (cutBaseGuestPaid - cutBaseInHand) / cutBaseGuestPaid * 100 : null;
}

class WeekdayStats {
  final int index; // 0 = Monday
  int nights = 0;
  int nightsWithInHand = 0;
  int available = 0;
  double inHand = 0;
  WeekdayStats(this.index);

  static const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String get name => names[index];
  double? get perNight => nightsWithInHand > 0 ? inHand / nightsWithInHand : null;
  double? get occupancy => available > 0 ? nights / available * 100 : null;
}

class LeadTimeStats {
  final String platform;
  final List<int> days = [];
  LeadTimeStats(this.platform);

  double get average => days.isEmpty ? 0 : days.reduce((a, b) => a + b) / days.length;
  int get median {
    final s = [...days]..sort();
    return s.isEmpty ? 0 : s[s.length ~/ 2];
  }

  /// Counts for: same week (0–7), 8–30, 31–90, 90+ days ahead.
  List<int> get histogram {
    final h = [0, 0, 0, 0];
    for (final d in days) {
      h[d <= 7 ? 0 : d <= 30 ? 1 : d <= 90 ? 2 : 3]++;
    }
    return h;
  }

  static const histogramLabels = ['≤ 7 days', '8–30', '31–90', '90+'];
}

class Gap {
  final String property;
  final DateTime start;
  final DateTime end; // exclusive
  Gap(this.property, this.start, this.end);
  int get nights => daysBetween(start, end);
}

class ForwardLook {
  final int days;
  final int nightsBooked;
  final int nightsAvailable;
  final double expectedGuestPaid;
  final List<Gap> gaps;
  ForwardLook(this.days, this.nightsBooked, this.nightsAvailable, this.expectedGuestPaid, this.gaps);
  double? get occupancy => nightsAvailable > 0 ? nightsBooked / nightsAvailable * 100 : null;
}

// ---------------------------------------------------------------------------
// Overlaps (double-booking alarm)
// ---------------------------------------------------------------------------

class Overlap {
  final String property;
  final String aId;
  final String bId;
  final DateTime start;
  final DateTime end;
  Overlap(this.property, this.aId, this.bId, this.start, this.end);
}

/// Every pair of active bookings/blocks on the same property that share a night.
List<Overlap> findOverlaps(List<Booking> bookings, List<Block> blocks, {String defaultProperty = '', List<String> properties = const []}) {
  String prop(String p) => InsightsData._prop(p, defaultProperty, properties);
  final items = <(String, String, DateTime, DateTime)>[
    for (final b in bookings.where((b) => b.isActive && b.nights > 0)) (b.id, prop(b.property), b.checkIn, b.checkOut),
    for (final k in blocks) (k.id, prop(k.property), k.startDate, k.endExclusive),
  ]..sort((a, b) => a.$3.compareTo(b.$3));
  final out = <Overlap>[];
  for (var i = 0; i < items.length; i++) {
    for (var j = i + 1; j < items.length; j++) {
      final a = items[i], b = items[j];
      if (!b.$3.isBefore(a.$4)) break; // sorted by start: later items start after a ends
      if (a.$2 != b.$2) continue;
      if (overlapNights(a.$3, a.$4, b.$3, b.$4) > 0) {
        out.add(Overlap(a.$2, a.$1, b.$1, b.$3, a.$4.isBefore(b.$4) ? a.$4 : b.$4));
      }
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Auto-generated insight cards
// ---------------------------------------------------------------------------

enum Tone { positive, negative, neutral, action }

class InsightCard {
  final String text;
  final Tone tone;
  final double score;
  final String kind;
  InsightCard(this.kind, this.text, this.tone, this.score);
}

/// Plain-language observations. Each one is only produced when there is enough
/// data behind it, and every number in it comes straight from the data.
List<InsightCard> generateInsights(InsightsData data, Period p, DateTime todayDay) {
  final cards = <InsightCard>[];
  final cur = data.forPeriod(p);
  final prev = data.forPeriod(p.previous);
  final periodName = switch (p.kind) {
    PeriodKind.week => 'this week',
    PeriodKind.month => 'in ${DateFormat('MMMM').format(p.start)}',
    PeriodKind.quarter => 'this quarter',
    PeriodKind.year => 'in ${p.start.year}',
    PeriodKind.custom => 'in this period',
  };
  final prevName = switch (p.kind) {
    PeriodKind.week => 'last week',
    PeriodKind.month => 'last month',
    PeriodKind.quarter => 'last quarter',
    PeriodKind.year => 'last year',
    PeriodKind.custom => 'the previous period',
  };

  // 1. Completed stays with no in-hand amount (always actionable).
  final missing = data.bookings.where((b) => b.status == 'completed' && b.pendingInHand).length;
  if (missing > 0) {
    cards.add(InsightCard('pending', '${plural(missing, 'completed stay')} still ${missing == 1 ? 'has' : 'have'} no in-hand amount entered.',
        Tone.action, 100 + missing.toDouble()));
  }

  // 2. Platform commission comparison (needs ≥2 platforms with ≥2 stays each).
  final plats = data.byPlatform(p).where((s) => s.staysWithBoth >= 2 && s.commissionPct != null && s.platform != 'Direct').toList()
    ..sort((a, b) => b.commissionPct!.compareTo(a.commissionPct!));
  if (plats.length >= 2) {
    final hi = plats.first, lo = plats.last;
    final diff = hi.commissionPct! - lo.commissionPct!;
    if (diff >= 3) {
      cards.add(InsightCard('commission',
          '${hi.platform} took ${hi.commissionPct!.round()}% of guest payments $periodName vs ${lo.commissionPct!.round()}% on ${lo.platform}.',
          Tone.neutral, 60 + diff));
    }
  }

  // 3. Best-paying platform per night.
  final perNight = data.byPlatform(p).where((s) => s.nightsWithInHand >= 4 && s.inHandPerNight != null).toList()
    ..sort((a, b) => b.inHandPerNight!.compareTo(a.inHandPerNight!));
  if (perNight.length >= 2) {
    final best = perNight.first, worst = perNight.last;
    final diff = best.inHandPerNight! - worst.inHandPerNight!;
    if (diff >= 200) {
      cards.add(InsightCard('platform-pay',
          '${best.platform} paid you the most per night $periodName: ${inr(best.inHandPerNight)} in hand vs ${inr(worst.inHandPerNight)} on ${worst.platform}.',
          Tone.positive, 55 + diff / 100));
    }
  }

  // 4. Weekend vs weekday nightly earnings (Fri & Sat nights = weekend).
  final wd = data.byWeekday(p);
  final we = [wd[4], wd[5]];
  final wk = [wd[0], wd[1], wd[2], wd[3], wd[6]];
  final weN = we.fold<int>(0, (a, w) => a + w.nightsWithInHand), wkN = wk.fold<int>(0, (a, w) => a + w.nightsWithInHand);
  if (weN >= 3 && wkN >= 3) {
    final weRate = we.fold<double>(0, (a, w) => a + w.inHand) / weN;
    final wkRate = wk.fold<double>(0, (a, w) => a + w.inHand) / wkN;
    final diff = weRate - wkRate;
    if (diff.abs() >= 100) {
      cards.add(InsightCard('weekend',
          diff > 0
              ? 'Weekends earned ${inr(diff)}/night more than weekdays $periodName.'
              : 'Weekdays earned ${inr(-diff)}/night more than weekends $periodName.',
          Tone.neutral, 45 + diff.abs() / 100));
    }
  }

  // 5. Empty nights in the next 14 days.
  final fl = data.forward(todayDay, 14);
  final emptyNights = fl.gaps.fold<int>(0, (a, g) => a + g.nights);
  if (emptyNights > 0 && emptyNights < 14 * data.propertyCount) {
    final counts = List.filled(7, 0);
    for (final g in fl.gaps) {
      for (final n in eachNight(g.start, g.end)) {
        counts[n.weekday - 1]++;
      }
    }
    final midweek = counts[0] + counts[1] + counts[2] + counts[3];
    final suffix = midweek / emptyNights >= 0.6 ? ', mostly Mon–Thu' : '';
    cards.add(InsightCard('gaps', 'You have ${plural(emptyNights, 'empty night')} in the next 14 days$suffix.', Tone.action, 70 + emptyNights.toDouble()));
  } else if (emptyNights == 14 * data.propertyCount && data.bookings.isNotEmpty) {
    cards.add(InsightCard('gaps', 'Nothing is booked for the next 14 days yet.', Tone.action, 75));
  }

  // 6. Best month so far this year (needs ≥2 months with stays).
  final year = todayDay.year;
  final months = [
    for (var mth = 1; mth <= todayDay.month; mth++)
      (DateTime.utc(year, mth, 1), data.metrics(DateTime.utc(year, mth, 1), DateTime.utc(year, mth + 1, 1)))
  ].where((e) => e.$2.nightsWithInHand > 0).toList();
  if (months.length >= 2) {
    months.sort((a, b) => b.$2.inHand.compareTo(a.$2.inHand));
    final best = months.first;
    cards.add(InsightCard('best-month',
        'Best month so far this year: ${DateFormat('MMMM').format(best.$1)} (${inr(best.$2.inHand)} in hand, ${pct(best.$2.occupancy)} occupancy).',
        Tone.positive, 40));
  }

  // 7. Profit vs previous period.
  final profitChange = pctChange(cur.profit, prev.profit);
  if (profitChange != null && cur.nightsWithInHand > 0 && prev.nightsWithInHand > 0 && profitChange.abs() >= 5) {
    cards.add(InsightCard('profit',
        'Profit is ${profitChange > 0 ? 'up' : 'down'} ${profitChange.abs().round()}% vs $prevName.',
        profitChange > 0 ? Tone.positive : Tone.negative, 50 + math.min(profitChange.abs(), 50) / 2));
  }

  // 8. Occupancy vs previous period.
  if (cur.occupancy != null && prev.occupancy != null && prev.nightsBooked > 0 && cur.nightsBooked > 0) {
    final diff = cur.occupancy! - prev.occupancy!;
    if (diff.abs() >= 10) {
      cards.add(InsightCard('occupancy',
          'Occupancy is ${pct(cur.occupancy)} $periodName, ${diff > 0 ? 'up' : 'down'} ${diff.abs().round()} points on $prevName.',
          diff > 0 ? Tone.positive : Tone.negative, 35 + diff.abs() / 2));
    }
  }

  // 9. Cancellations.
  if (cur.cancellations >= 2 && (cur.cancellationRate ?? 0) >= 20) {
    cards.add(InsightCard('cancellations',
        '${plural(cur.cancellations, 'cancellation')} $periodName (${pct(cur.cancellationRate)} of bookings), losing ${plural(cur.nightsLost, 'night')}.',
        Tone.negative, 45));
  }

  cards.sort((a, b) => b.score.compareTo(a.score));
  return cards;
}
