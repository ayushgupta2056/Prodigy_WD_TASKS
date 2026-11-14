import 'dart:math' as math;

import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';
import '../../theme/icons.dart';

import '../../core/dates.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../app_scope.dart';
import '../widgets/booking_widgets.dart';
import '../widgets/common.dart';
import 'block_form.dart';
import 'booking_form.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = startOfMonth(today());
  String? _property;
  DateTime? _selStart;
  DateTime? _selEnd;
  int _dir = 1;

  void _shift(int n) => setState(() {
        _dir = n;
        _month = addMonths(_month, n);
      });

  void _onDayTap(DateTime d) {
    if (_selStart != null) {
      setState(() {
        if (d.isBefore(_selStart!)) {
          _selEnd = _selStart;
          _selStart = d;
        } else {
          _selEnd = d;
        }
      });
      _askRangeAction();
      return;
    }
    _showDay(d);
  }

  void _onDayLongPress(DateTime d) => setState(() {
        _selStart = d;
        _selEnd = null;
      });

  void _clearSelection() => setState(() {
        _selStart = null;
        _selEnd = null;
      });

  Future<void> _askRangeAction() async {
    final s = _selStart!, e = _selEnd ?? _selStart!;
    final nights = daysBetween(s, e) + 1;
    final choice = await showAdaptiveSheet<String>(context, builder: (ctx) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${fmtRange(s, e)} · ${plural(nights, 'night')}', style: AppText.h2(ctx)),
        const SizedBox(height: Space.xs),
        Text('What would you like to do with these dates?', style: AppText.label(ctx)),
        const SizedBox(height: Space.xl),
        FilledButton.icon(onPressed: () => Navigator.pop(ctx, 'booking'), icon: const Icon(LucideIcons300.userPlus, size: 18), label: const Text('Add a manual booking')),
        const SizedBox(height: Space.md),
        OutlinedButton.icon(onPressed: () => Navigator.pop(ctx, 'block'), icon: const Icon(LucideIcons300.ban, size: 18), label: const Text('Block these dates')),
        const SizedBox(height: Space.sm),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ]);
    });
    if (!mounted) return;
    if (choice == 'booking') {
      await showBookingForm(context, checkIn: s, checkOut: addDays(e, 1), property: _property);
    } else if (choice == 'block') {
      await showBlockForm(context, start: s, end: e, property: _property);
    }
    _clearSelection();
  }

  void _showDay(DateTime d) {
    final repo = context.repoRead;
    final stays = repo.view.bookings
        .where((b) => (_property == null || _propOf(b.property) == _property) && b.nights > 0 && (b.isActive || b.isCancelled))
        .where((b) => (!d.isBefore(b.checkIn) && d.isBefore(b.checkOut)) || b.checkOut == d)
        .toList();
    final blocks = repo.view.blocks.where((k) => (_property == null || _propOf(k.property) == _property) && !d.isBefore(k.startDate) && !d.isAfter(k.endDate)).toList();
    showAdaptiveSheet<void>(context, builder: (ctx) {
      return SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(DateFormat('EEEE, d MMMM').format(d), style: AppText.h2(ctx)),
          const SizedBox(height: Space.md),
          if (stays.isEmpty && blocks.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: Space.md), child: Text('Free night.', style: AppText.body(ctx).copyWith(color: ctx.colors.muted))),
          for (final b in stays)
            BookingTile(b, caption: b.checkOut == d ? 'Checks out · ${b.platform}' : (b.checkIn == d ? 'Checks in · ${b.platform} · ${plural(b.nights, 'night')}' : '${b.platform} · until ${fmtDayMonth(b.checkOut)}')),
          for (final k in blocks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const _HatchSwatch(),
              title: Text('Blocked · ${k.reason}', style: AppText.title(ctx)),
              subtitle: Text('${fmtRange(k.startDate, k.endDate)}${k.notes.isEmpty ? '' : ' · ${k.notes}'}', style: AppText.label(ctx)),
              trailing: const Icon(LucideIcons300.pencil, size: 18),
              onTap: () {
                Navigator.pop(ctx);
                showBlockForm(context, existing: k);
              },
            ),
          const SizedBox(height: Space.lg),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  showBookingForm(context, checkIn: d, checkOut: addDays(d, 1), property: _property);
                },
                icon: const Icon(LucideIcons300.userPlus, size: 18),
                label: const Text('Add booking'),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  showBlockForm(context, start: d, end: d, property: _property);
                },
                icon: const Icon(LucideIcons300.ban, size: 18),
                label: const Text('Block'),
              ),
            ),
          ]),
          const SizedBox(height: Space.sm),
          Text('Tip: long-press a date, then tap another, to select a range.', style: AppText.label(ctx), textAlign: TextAlign.center),
        ]),
      );
    });
  }

  String _propOf(String p) => p.isNotEmpty ? p : context.repoRead.defaultProperty;

  @override
  Widget build(BuildContext context) {
    final repo = context.repo;
    final c = context.colors;
    final props = repo.properties;
    final bookings = repo.view.bookings.where((b) => b.isActive && b.nights > 0 && (_property == null || _propOf(b.property) == _property)).toList();
    final blocks = repo.view.blocks.where((k) => _property == null || _propOf(k.property) == _property).toList();
    final overlapIds = repo.overlapIds;
    final monthEnd = addMonths(_month, 1);
    final inMonth = bookings.where((b) => overlapNights(b.checkIn, b.checkOut, _month, monthEnd) > 0).toList()..sort((a, b) => a.checkIn.compareTo(b.checkIn));
    final booked = inMonth.fold<int>(0, (a, b) => a + overlapNights(b.checkIn, b.checkOut, _month, monthEnd));
    final wide = context.isWide;

    final header = Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DateFormat('MMMM').format(_month), style: AppText.h1(context)),
          Text('${_month.year} · ${plural(booked, 'night')} booked', style: AppText.label(context)),
        ]),
      ),
      if (startOfMonth(today()) != _month)
        TextButton(onPressed: () => setState(() => _month = startOfMonth(today())), child: const Text('Today')),
      _RoundIcon(LucideIcons300.chevronLeft, () => _shift(-1), 'Previous month'),
      const SizedBox(width: 6),
      _RoundIcon(LucideIcons300.chevronRight, () => _shift(1), 'Next month'),
    ]);

    final grid = GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() > 250) _shift(v < 0 ? 1 : -1);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(position: Tween(begin: Offset(0.04 * _dir, 0), end: Offset.zero).animate(anim), child: child),
        ),
        child: _MonthGrid(
          key: ValueKey(_month),
          month: _month,
          bookings: bookings,
          blocks: blocks,
          overlapIds: overlapIds,
          selStart: _selStart,
          selEnd: _selEnd,
          onDayTap: _onDayTap,
          onDayLongPress: _onDayLongPress,
          onBookingTap: (b) => openBooking(context, b.id),
          onBlockTap: (k) => showBlockForm(context, existing: k),
        ),
      ),
    );

    final list = AppCard(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Stays in ${DateFormat('MMMM').format(_month)}', style: AppText.title(context)),
        if (inMonth.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: Space.lg), child: Text('No stays this month.', style: AppText.body(context).copyWith(color: c.muted))),
        for (final b in inMonth) BookingTile(b),
      ]),
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'cal-fab',
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        elevation: 2,
        onPressed: () => showBookingForm(context, property: _property),
        icon: const Icon(LucideIcons300.plus),
        label: const Text('Booking'),
      ),
      body: SafeArea(
        child: PageBody(
          onRefresh: () => repo.sync(checkEmails: true),
          children: [
            const SizedBox(height: Space.lg),
            header,
            const SizedBox(height: Space.lg),
            OverlapBanner(onTap: () {
              final o = repo.overlaps.first;
              setState(() => _month = startOfMonth(o.start));
            }),
            if (props.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    ChoiceChip(label: const Text('All'), selected: _property == null, onSelected: (_) => setState(() => _property = null)),
                    for (final p in props)
                      Padding(padding: const EdgeInsets.only(left: 8), child: ChoiceChip(label: Text(p), selected: _property == p, onSelected: (_) => setState(() => _property = p))),
                  ]),
                ),
              ),
            if (_selStart != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: AppCard(
                  color: c.accentSoft,
                  borderColor: Colors.transparent,
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.xs, Space.xs, Space.xs),
                  child: Row(children: [
                    Expanded(child: Text('From ${fmtDayMonth(_selStart!)}: tap the last night', style: AppText.label(context).copyWith(color: c.accent))),
                    TextButton(onPressed: _clearSelection, child: const Text('Cancel')),
                  ]),
                ),
              ),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 5, child: AppCard(padding: const EdgeInsets.all(Space.md), child: grid)),
                const SizedBox(width: Space.lg),
                Expanded(flex: 2, child: Column(children: [const _Legend(), const SizedBox(height: Space.md), list])),
              ])
            else ...[
              AppCard(padding: const EdgeInsets.fromLTRB(Space.xs, Space.md, Space.xs, Space.sm), child: grid),
              const SizedBox(height: Space.md),
              const _Legend(),
              const SizedBox(height: Space.md),
              list,
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _RoundIcon(this.icon, this.onTap, this.tooltip);
  @override
  Widget build(BuildContext context) => Tooltip(message: tooltip, child: Material(
        color: context.colors.surface,
        shape: CircleBorder(side: BorderSide(color: context.colors.hairline)),
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, size: 18))),
      ));
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    Widget item(Widget dot, String label) => Row(mainAxisSize: MainAxisSize.min, children: [dot, const SizedBox(width: 6), Text(label, style: AppText.label(context))]);
    return Wrap(spacing: 14, runSpacing: 8, children: [
      for (final p in platforms.where((p) => p != 'Other')) item(PlatformLogo(p, size: 15), p),
      item(const SizedBox(width: 14, height: 10, child: _HatchSwatch()), 'Blocked'),
      item(Container(width: 10, height: 10, decoration: BoxDecoration(color: context.colors.danger, shape: BoxShape.circle)), 'Overlap'),
    ]);
  }
}

class _HatchSwatch extends StatelessWidget {
  const _HatchSwatch();
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CustomPaint(size: const Size(28, 28), painter: _HatchPainter(context.colors.surfaceAlt, context.colors.muted.withValues(alpha: 0.45))),
      );
}

// ---------------------------------------------------------------------------
// Month grid with stays drawn as continuous rounded bars
// ---------------------------------------------------------------------------

class _Seg {
  final Object item; // Booking or Block
  final double x0; // in day units 0..7
  final double x1;
  final bool startsHere;
  final bool endsHere;
  int lane = 0;
  double room = 0; // day units free for the name, up to the next bar in this lane
  _Seg(this.item, this.x0, this.x1, this.startsHere, this.endsHere);
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final List<Booking> bookings;
  final List<Block> blocks;
  final Set<String> overlapIds;
  final DateTime? selStart;
  final DateTime? selEnd;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime> onDayLongPress;
  final ValueChanged<Booking> onBookingTap;
  final ValueChanged<Block> onBlockTap;

  const _MonthGrid({
    super.key,
    required this.month,
    required this.bookings,
    required this.blocks,
    required this.overlapIds,
    required this.selStart,
    required this.selEnd,
    required this.onDayTap,
    required this.onDayLongPress,
    required this.onBookingTap,
    required this.onBlockTap,
  });

  List<_Seg> _segments(DateTime weekStart) {
    final weekEnd = addDays(weekStart, 7);
    final segs = <_Seg>[];
    void add(Object item, DateTime s, DateTime e) {
      if (!s.isBefore(weekEnd) || e.isBefore(weekStart)) return;
      if (!e.isAfter(weekStart) && !(e == weekStart)) return;
      final starts = !s.isBefore(weekStart);
      final ends = e.isBefore(weekEnd);
      final x0 = starts ? daysBetween(weekStart, s) + 0.5 : 0.0;
      final x1 = ends ? daysBetween(weekStart, e) + 0.5 : 7.0;
      if (x1 - x0 < 0.4) return;
      segs.add(_Seg(item, x0, x1, starts, ends));
    }

    for (final b in bookings) {
      add(b, b.checkIn, b.checkOut);
    }
    for (final k in blocks) {
      add(k, k.startDate, k.endExclusive);
    }
    segs.sort((a, b) => a.x0.compareTo(b.x0));
    final laneEnds = <double>[];
    for (final s in segs) {
      var lane = laneEnds.indexWhere((end) => end <= s.x0 + 0.01);
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.add(s.x1);
      } else {
        laneEnds[lane] = s.x1;
      }
      s.lane = lane;
    }
    for (final s in segs) {
      final next = segs.where((o) => o.lane == s.lane && o.x0 >= s.x1 - 0.01).map((o) => o.x0).fold<double>(7, math.min);
      s.room = next - s.x0;
    }
    return segs;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final first = startOfWeek(month);
    final last = addMonths(month, 1);
    final weeks = <DateTime>[for (var w = first; w.isBefore(last); w = addDays(w, 7)) w];
    final t = today();
    const dayH = 30.0, laneH = 26.0, rowPad = 8.0;

    bool selected(DateTime d) {
      if (selStart == null) return false;
      final e = selEnd ?? selStart!;
      return !d.isBefore(selStart!) && !d.isAfter(e);
    }

    return LayoutBuilder(builder: (context, box) {
      final cw = box.maxWidth / 7;
      return Column(children: [
        Row(children: [
          for (final n in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
            SizedBox(width: cw, child: Center(child: Text(n, style: AppText.overline(context)))),
        ]),
        const SizedBox(height: Space.sm),
        for (final w in weeks)
          Builder(builder: (context) {
            final segs = _segments(w);
            final lanes = segs.isEmpty ? 1 : segs.map((s) => s.lane).reduce(math.max) + 1;
            final h = dayH + lanes * laneH + rowPad;
            return Container(
              height: math.max(h, 74),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline.withValues(alpha: 0.7)))),
              child: Stack(clipBehavior: Clip.none, children: [
                // Day cells
                for (var i = 0; i < 7; i++)
                  Positioned(
                    left: i * cw,
                    top: 0,
                    width: cw,
                    bottom: 0,
                    child: Builder(builder: (context) {
                      final d = addDays(w, i);
                      final inMonth = d.month == month.month;
                      final isToday = d == t;
                      final sel = selected(d);
                      return InkWell(
                        onTap: () => onDayTap(d),
                        onLongPress: () => onDayLongPress(d),
                        child: Container(
                          color: sel ? c.accentSoft : (isToday ? c.accent.withValues(alpha: 0.05) : null),
                          padding: const EdgeInsets.only(top: 6),
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: isToday ? BoxDecoration(color: c.accent, shape: BoxShape.circle) : null,
                            child: Text('${d.day}',
                                style: AppText.num(context, size: 13).copyWith(
                                  color: isToday ? c.onAccent : (inMonth ? (d.isBefore(t) ? c.muted : c.ink) : c.muted.withValues(alpha: 0.4)),
                                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                )),
                          ),
                        ),
                      );
                    }),
                  ),
                // Bars
                for (final s in segs)
                  Positioned(
                    left: s.x0 * cw + 1,
                    width: (s.x1 - s.x0) * cw - 2,
                    top: dayH + 4 + s.lane * laneH,
                    height: laneH - 5,
                    child: _Bar(seg: s, overlap: overlapIds.contains(_id(s.item)), onTap: () {
                      final it = s.item;
                      if (it is Booking) onBookingTap(it);
                      if (it is Block) onBlockTap(it);
                    }),
                  ),
                // Full guest names, drawn on top and not clipped to the bar.
                for (final s in segs)
                  if (s.item is Booking && (s.startsHere || s.x0 == 0))
                    Positioned(
                      left: s.x0 * cw + (s.startsHere ? 22 : 6),
                      width: math.max(0, s.room * cw - (s.startsHere ? 24 : 8)),
                      top: dayH + 4 + s.lane * laneH,
                      height: laneH - 5,
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text((s.item as Booking).guestName.trim().isEmpty ? 'Guest' : (s.item as Booking).guestName.trim(),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                              style: AppText.label(context).copyWith(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: overlapIds.contains((s.item as Booking).id)
                                      ? (s.x1 - s.x0 >= s.room - 0.01 ? Colors.white : c.danger)
                                      : _ink(context, (s.item as Booking).platform))),
                        ),
                      ),
                    ),
              ]),
            );
          }),
      ]);
    });
  }

  static String _id(Object o) => o is Booking ? o.id : (o as Block).id;

  /// Platform colour darkened (light theme) or lightened (dark) for text.
  static Color _ink(BuildContext context, String platform) {
    final pc = PlatformColors.of(context, platform);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? Color.lerp(pc, Colors.white, 0.35)! : Color.lerp(pc, Colors.black, 0.4)!;
  }
}

class _Bar extends StatelessWidget {
  final _Seg seg;
  final bool overlap;
  final VoidCallback onTap;
  const _Bar({required this.seg, required this.overlap, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final it = seg.item;
    final r = const Radius.circular(Radii.bar);
    final radius = BorderRadius.horizontal(left: seg.startsHere ? r : Radius.zero, right: seg.endsHere ? r : Radius.zero);
    if (it is Block) {
      return GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: radius,
          child: CustomPaint(
            painter: _HatchPainter(overlap ? c.dangerSoft : c.surfaceAlt, overlap ? c.danger.withValues(alpha: 0.5) : c.muted.withValues(alpha: 0.4)),
            child: Container(
              decoration: BoxDecoration(borderRadius: radius, border: overlap ? Border.all(color: c.danger, width: 1.4) : null),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerLeft,
              child: (seg.startsHere || seg.x0 == 0)
                  ? _FitLabel(const ['Blocked', 'Blk'], style: AppText.label(context).copyWith(fontSize: 11, color: c.inkSoft, fontWeight: FontWeight.w600))
                  : null,
            ),
          ),
        ),
      );
    }
    final b = it as Booking;
    final pc = PlatformColors.of(context, b.platform);
    final bg = overlap ? c.danger : pc;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: overlap ? bg : bg.withValues(alpha: dark ? 0.38 : 0.24),
      shape: RoundedRectangleBorder(borderRadius: radius, side: overlap ? BorderSide.none : BorderSide(color: pc, width: 1.1)),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Align(
          alignment: Alignment.centerLeft,
          child: seg.startsHere
              ? Padding(padding: const EdgeInsets.only(left: 3), child: PlatformLogo(b.platform, size: 16))
              : null,
        ),
      ),
    );
  }
}

/// Shows the first of [options] that fits the space (full name, first name,
/// initials), so even a one-night stay on a phone shows who it is.
class _FitLabel extends StatelessWidget {
  final List<String> options;
  final TextStyle style;
  const _FitLabel(this.options, {required this.style});

  static bool fits(String text, TextStyle style, double width) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), maxLines: 1, textDirection: TextDirection.ltr)..layout();
    return tp.width <= width;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final scaled = style.copyWith(fontSize: MediaQuery.textScalerOf(context).scale(style.fontSize ?? 12));
        final text = options.firstWhere((o) => fits(o, scaled, box.maxWidth), orElse: () => '');
        return Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.clip, style: style);
      });
}

class _HatchPainter extends CustomPainter {
  final Color bg;
  final Color line;
  _HatchPainter(this.bg, this.line);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    final p = Paint()
      ..color = line
      ..strokeWidth = 1.2;
    for (double x = -size.height; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.bg != bg || old.line != line;
}
