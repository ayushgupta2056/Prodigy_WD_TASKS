import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import '../../theme/icons.dart';

import '../../core/dates.dart';
import '../../core/format.dart';
import '../../core/insights.dart';
import '../../theme/app_theme.dart';
import '../app_scope.dart';
import '../export_actions.dart';
import '../widgets/common.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  PeriodKind _kind = PeriodKind.month;
  late Period _period = Period.containing(PeriodKind.month, today());
  String? _property;

  void _setKind(PeriodKind k) async {
    if (k == PeriodKind.custom) {
      final r = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2018),
        lastDate: DateTime(2035),
        initialDateRange: DateTimeRange(start: DateTime(_period.start.year, _period.start.month, _period.start.day), end: DateTime(_period.end.year, _period.end.month, _period.end.day).subtract(const Duration(days: 1))),
      );
      if (r == null) return;
      setState(() {
        _kind = k;
        _period = Period.custom(DateTime.utc(r.start.year, r.start.month, r.start.day), DateTime.utc(r.end.year, r.end.month, r.end.day));
      });
      return;
    }
    setState(() {
      _kind = k;
      _period = Period.containing(k, today());
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.repo;
    final data = repo.insights(property: _property);
    final p = _period;
    final m = data.forPeriod(p);
    final prev = data.forPeriod(p.previous);
    final ly = p.sameLastYear == null ? null : data.forPeriod(p.sameLastYear!);
    double? vsLy(double? cur, double? Function(Metrics) g) => ly == null || !ly.hasData ? null : pctChange(cur, g(ly));
    final cards = generateInsights(data, p, today()).take(6).toList();
    final wide = context.isWide;

    final kpis = TileGrid(children: [
      StatTile(label: 'In hand', icon: LucideIcons300.wallet, value: m.inHand, change: pctChange(m.inHand, prev.inHand), changeLastYear: vsLy(m.inHand, (x) => x.inHand),
          footnote: m.pendingInHandStays > 0 ? '${m.pendingInHandStays} pending' : null),
      StatTile(label: 'Guest paid', icon: LucideIcons300.receipt, value: m.guestPaid, change: pctChange(m.guestPaid, prev.guestPaid), changeLastYear: vsLy(m.guestPaid, (x) => x.guestPaid)),
      StatTile(label: 'Platform cut', icon: LucideIcons300.scissors, value: m.cut, goodWhenUp: false, change: pctChange(m.cut, prev.cut), footnote: pct(m.cutPct, decimals: 1)),
      StatTile(label: 'Profit', icon: LucideIcons300.trendingUp, value: m.profit, change: pctChange(m.profit, prev.profit), changeLastYear: vsLy(m.profit, (x) => x.profit)),
      StatTile(label: 'Costs', icon: LucideIcons300.brushCleaning, value: m.costs, goodWhenUp: false, change: pctChange(m.costs, prev.costs)),
      StatTile(label: 'Occupancy', icon: LucideIcons300.bed, value: m.occupancy, format: (v) => '${v.round()}%', change: pctChange(m.occupancy, prev.occupancy), changeLastYear: vsLy(m.occupancy, (x) => x.occupancy),
          footnote: '${m.nightsBooked}/${m.nightsAvailable} nights'),
      StatTile(label: 'ADR · per booked night', icon: LucideIcons300.moonStar, value: m.adr, change: pctChange(m.adr, prev.adr)),
      StatTile(label: 'RevPAN · per available night', icon: LucideIcons300.gauge, value: m.revpan, change: pctChange(m.revpan, prev.revpan)),
      StatTile(label: 'Stays', icon: LucideIcons300.users, value: m.stays.toDouble(), format: (v) => '${v.round()}', change: pctChange(m.stays, prev.stays),
          footnote: m.avgLengthOfStay == null ? null : 'avg ${m.avgLengthOfStay!.toStringAsFixed(1)} nights'),
      StatTile(label: 'Nights booked', icon: LucideIcons300.calendarCheck, value: m.nightsBooked.toDouble(), format: (v) => '${v.round()}', change: pctChange(m.nightsBooked, prev.nightsBooked)),
      StatTile(label: 'Cancellations', icon: LucideIcons300.circleX, value: m.cancellations.toDouble(), format: (v) => '${v.round()}', goodWhenUp: false,
          footnote: m.cancellations == 0 ? null : '${pct(m.cancellationRate)} · ${plural(m.nightsLost, 'night')} lost'),
    ]);

    final charts = <Widget>[
      _ChartCard(title: 'Earnings', subtitle: 'In hand vs guest paid, with profit', child: _EarningsChart(data.buckets(p))),
      _ChartCard(title: 'Occupancy', subtitle: 'Share of available nights booked', child: _OccupancyChart(data.buckets(p))),
      _ChartCard(title: 'Platform mix', child: _PlatformMix(data.byPlatform(p))),
      _ChartCard(title: 'Which platform pays best', subtitle: 'In hand per night and effective commission', child: _PlatformTable(data.byPlatform(p))),
      _ChartCard(title: 'Day of the week', subtitle: 'Nights booked and in hand per night', child: _WeekdayChart(data.byWeekday(p))),
      _ChartCard(title: 'Booking lead time', subtitle: 'Days between booking and check-in', child: _LeadTimes(data.leadTimes(p))),
    ];

    return Scaffold(
      body: SafeArea(
        child: PageBody(
          onRefresh: () => repo.sync(),
          children: [
            const SizedBox(height: Space.lg),
            Row(children: [
              Expanded(child: Text('Insights', style: AppText.h1(context))),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: () => exportToExcel(context, period: p, property: _property, scopeLabel: p.label),
                icon: const Icon(LucideIcons300.fileSpreadsheet, size: 18),
                label: const Text('Export'),
              ),
            ]),
            const SizedBox(height: Space.lg),
            _PeriodTabs(value: _kind, onChanged: _setKind),
            const SizedBox(height: Space.md),
            Row(children: [
              IconButton(onPressed: () => setState(() => _period = _period.shift(-1)), icon: const Icon(LucideIcons300.chevronLeft)),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(p.label, key: ValueKey(p), textAlign: TextAlign.center, style: AppText.h2(context)),
                ),
              ),
              IconButton(onPressed: () => setState(() => _period = _period.shift(1)), icon: const Icon(LucideIcons300.chevronRight)),
            ]),
            if (repo.properties.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: Space.sm),
                child: Wrap(spacing: 8, children: [
                  ChoiceChip(label: const Text('All properties'), selected: _property == null, onSelected: (_) => setState(() => _property = null)),
                  for (final pr in repo.properties) ChoiceChip(label: Text(pr), selected: _property == pr, onSelected: (_) => setState(() => _property = pr)),
                ]),
              ),
            const SizedBox(height: Space.lg),
            if (!m.hasData && !prev.hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Space.xxxl),
                child: EmptyState(icon: LucideIcons300.chartLine, title: 'No stays in this period', message: 'Move back with the arrows, or pick a longer period.'),
              )
            else ...[
              kpis,
              if (cards.isNotEmpty) ...[
                const SectionHeader('What stands out'),
                TileGrid(phoneColumns: 1, wideColumns: 3, children: [for (var i = 0; i < cards.length; i++) EaseIn(index: i, child: _InsightTile(cards[i]))]),
              ],
              const SectionHeader('Trends'),
              if (wide)
                for (var i = 0; i < charts.length; i += 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.lg),
                    child: IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(child: charts[i]),
                        const SizedBox(width: Space.lg),
                        Expanded(child: i + 1 < charts.length ? charts[i + 1] : const SizedBox()),
                      ]),
                    ),
                  )
              else
                for (final ch in charts) Padding(padding: const EdgeInsets.only(bottom: Space.md), child: ch),
            ],
            SectionHeader('${p.start.year} at a glance', subtitle: 'Darker = busier'),
            _ChartCard(child: _YearHeatmap(data.yearHeatmap(p.start.year))),
            const SectionHeader('Looking ahead'),
            _ForwardLook(data),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Week / Month / Quarter / Year / Custom as a soft pill tab bar.
class _PeriodTabs extends StatelessWidget {
  final PeriodKind value;
  final ValueChanged<PeriodKind> onChanged;
  const _PeriodTabs({required this.value, required this.onChanged});
  static const _labels = {
    PeriodKind.week: 'Week',
    PeriodKind.month: 'Month',
    PeriodKind.quarter: 'Quarter',
    PeriodKind.year: 'Year',
    PeriodKind.custom: 'Custom',
  };
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.surfaceAlt.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(Radii.chip)),
      child: Row(children: [
        for (final e in _labels.entries)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: value == e.key ? c.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(Radii.chip),
                  boxShadow: value == e.key ? [BoxShadow(color: c.shadow, blurRadius: 8, offset: const Offset(0, 2))] : null,
                ),
                alignment: Alignment.center,
                child: Text(e.value,
                    maxLines: 1,
                    style: AppText.label(context).copyWith(color: value == e.key ? c.ink : c.muted, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  const _ChartCard({this.title, this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (title != null) Text(title!, style: AppText.title(context)),
          if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: AppText.label(context))),
          if (title != null) const SizedBox(height: Space.xl),
          child,
        ]),
      );
}

class _InsightTile extends StatelessWidget {
  final InsightCard card;
  const _InsightTile(this.card);
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, color) = switch (card.tone) {
      Tone.positive => (LucideIcons300.trendingUp, c.positive),
      Tone.negative => (LucideIcons300.trendingDown, c.negative),
      Tone.action => (LucideIcons300.bellRing, c.warning),
      Tone.neutral => (LucideIcons300.lightbulb, c.accent),
    };
    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: Space.md),
        Expanded(child: Text(card.text, style: AppText.body(context).copyWith(color: c.ink))),
      ]),
    );
  }
}

FlTitlesData _titles(BuildContext context, List<String> labels, {String Function(double)? left, double? leftInterval}) {
  final step = math.max(1, (labels.length / 7).ceil());
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: left != null,
        reservedSize: 46,
        interval: leftInterval,
        getTitlesWidget: (v, meta) => v == meta.max ? const SizedBox() : SideTitleWidget(meta: meta, child: Text(left!(v), style: AppText.label(context).copyWith(fontSize: 10.5))),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 26,
        interval: 1,
        getTitlesWidget: (v, meta) {
          final i = v.round();
          if (i < 0 || i >= labels.length || i % step != 0 || (v - i).abs() > 0.01) return const SizedBox();
          return SideTitleWidget(meta: meta, child: Text(labels[i], style: AppText.label(context).copyWith(fontSize: 10.5)));
        },
      ),
    ),
  );
}

FlGridData _grid(BuildContext context) => FlGridData(
      show: true,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) => FlLine(color: context.colors.hairline.withValues(alpha: 0.7), strokeWidth: 1, dashArray: [3, 5]),
    );

class _EarningsChart extends StatelessWidget {
  final List<Bucket> buckets;
  const _EarningsChart(this.buckets);
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (buckets.every((b) => b.m.guestPaid == 0)) return const _NoData();
    final maxY = buckets.map((b) => math.max(b.m.guestPaid, b.m.inHand)).reduce(math.max) * 1.15;
    // In-hand amounts arrive after a stay, so future buckets are left blank
    // instead of being drawn as zero.
    final t = today();
    LineChartBarData line(List<double?> ys, Color color, {bool area = false, bool dashed = false, double width = 2.4}) => LineChartBarData(
          spots: [for (var i = 0; i < ys.length; i++) ys[i] == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), ys[i]!)],
          isCurved: true,
          curveSmoothness: 0.28,
          preventCurveOverShooting: true,
          color: color,
          barWidth: width,
          isStrokeCapRound: true,
          dashArray: dashed ? [5, 5] : null,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: area,
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)]),
          ),
        );
    final series = [
      ('Guest paid', c.muted.withValues(alpha: 0.7)),
      ('In hand', c.accent),
      ('Profit', c.warning),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY <= 0 ? 1 : maxY,
            gridData: _grid(context),
            borderData: FlBorderData(show: false),
            titlesData: _titles(context, [for (final b in buckets) b.label], left: (v) => inrCompact(v)),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => c.ink,
                tooltipBorderRadius: BorderRadius.circular(10),
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem('${series[s.barIndex].$1}: ${inr(s.y)}', AppText.label(context).copyWith(color: c.background, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            lineBarsData: [
              line([for (final b in buckets) b.m.guestPaid], series[0].$2, width: 1.6),
              line([for (final b in buckets) b.start.isAfter(t) ? null : b.m.inHand], series[1].$2, area: true),
              line([for (final b in buckets) b.start.isAfter(t) ? null : b.m.profit], series[2].$2, dashed: true, width: 1.8),
            ],
          ),
          duration: const Duration(milliseconds: 500),
        ),
      ),
      const SizedBox(height: Space.md),
      Wrap(spacing: 16, children: [for (final s in series) _LegendDot(s.$1, s.$2)]),
    ]);
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot(this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: AppText.label(context)),
      ]);
}

class _OccupancyChart extends StatelessWidget {
  final List<Bucket> buckets;
  const _OccupancyChart(this.buckets);
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (buckets.every((b) => b.m.nightsBooked == 0)) return const _NoData();
    final w = math.max(4.0, math.min(22.0, 220 / buckets.length));
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: 100,
          minY: 0,
          gridData: _grid(context),
          borderData: FlBorderData(show: false),
          titlesData: _titles(context, [for (final b in buckets) b.label], left: (v) => '${v.round()}%', leftInterval: 25),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => c.ink,
              tooltipBorderRadius: BorderRadius.circular(10),
              getTooltipItem: (g, _, rod, __) => BarTooltipItem(
                '${buckets[g.x].label}: ${pct(buckets[g.x].m.occupancy)}\n${buckets[g.x].m.nightsBooked}/${buckets[g.x].m.nightsAvailable} nights',
                AppText.label(context).copyWith(color: c.background, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < buckets.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: math.min(100, buckets[i].m.occupancy ?? 0),
                  width: w,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(w / 2.5)),
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [c.accent.withValues(alpha: 0.55), c.accent]),
                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: 100, color: c.surfaceAlt.withValues(alpha: 0.6)),
                ),
              ]),
          ],
        ),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }
}

class _PlatformMix extends StatefulWidget {
  final List<PlatformStats> stats;
  const _PlatformMix(this.stats);
  @override
  State<_PlatformMix> createState() => _PlatformMixState();
}

class _PlatformMixState extends State<_PlatformMix> {
  String _metric = 'In hand';
  int _touched = -1;

  double _value(PlatformStats s) => switch (_metric) {
        'Bookings' => s.stays.toDouble(),
        'Nights' => s.nights.toDouble(),
        'Profit' => math.max(0, s.profit),
        _ => s.inHand,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final stats = widget.stats.where((s) => _value(s) > 0).toList();
    final total = stats.fold<double>(0, (a, s) => a + _value(s));
    String fmt(double v) => _metric == 'Bookings' || _metric == 'Nights' ? '${v.round()}' : inr(v);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final mtr in ['Bookings', 'Nights', 'In hand', 'Profit'])
          ChoiceChip(label: Text(mtr), selected: _metric == mtr, onSelected: (_) => setState(() => _metric = mtr), visualDensity: VisualDensity.compact),
      ]),
      const SizedBox(height: Space.lg),
      if (total == 0)
        const _NoData()
      else
        Row(children: [
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(alignment: Alignment.center, children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2.5,
                  centerSpaceRadius: 48,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(touchCallback: (e, r) => setState(() => _touched = e.isInterestedForInteractions ? (r?.touchedSection?.touchedSectionIndex ?? -1) : -1)),
                  sections: [
                    for (var i = 0; i < stats.length; i++)
                      PieChartSectionData(value: _value(stats[i]), color: PlatformColors.of(context, stats[i].platform), radius: i == _touched ? 26 : 21, showTitle: false),
                  ],
                ),
                duration: const Duration(milliseconds: 400),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_metric == 'Bookings' || _metric == 'Nights' ? fmt(total) : inrCompact(total), style: AppText.money(context, size: 17)),
                Text(_metric.toLowerCase(), style: AppText.label(context).copyWith(fontSize: 11)),
              ]),
            ]),
          ),
          const SizedBox(width: Space.xl),
          Expanded(
            child: Column(children: [
              for (final s in stats)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    PlatformDot(s.platform),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.platform, style: AppText.body(context).copyWith(color: c.ink), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${(100 * _value(s) / total).round()}%', style: AppText.num(context, size: 13).copyWith(color: c.ink, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ),
        ]),
    ]);
  }
}

class _PlatformTable extends StatelessWidget {
  final List<PlatformStats> stats;
  const _PlatformTable(this.stats);
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = stats.where((s) => s.nights > 0).toList()
      ..sort((a, b) => (b.inHandPerNight ?? -1).compareTo(a.inHandPerNight ?? -1));
    if (rows.isEmpty) return const _NoData();
    final best = rows.first.inHandPerNight ?? 0;
    TextStyle h = AppText.label(context).copyWith(fontSize: 11.5);
    return Column(children: [
      Row(children: [
        Expanded(flex: 3, child: Text('Platform', style: h)),
        Expanded(flex: 3, child: Text('Per night', style: h, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text('Cut', style: h, textAlign: TextAlign.right)),
        Expanded(flex: 2, child: Text('Nights', style: h, textAlign: TextAlign.right)),
      ]),
      const SizedBox(height: Space.sm),
      for (final s in rows) ...[
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: Row(children: [PlatformDot(s.platform), const SizedBox(width: 8), Flexible(child: Text(s.platform, style: AppText.body(context).copyWith(color: c.ink), overflow: TextOverflow.ellipsis))]),
            ),
            Expanded(
              flex: 3,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(inr(s.inHandPerNight), style: AppText.money(context, size: 14.5).copyWith(color: s.inHandPerNight == best && rows.length > 1 ? c.positive : null)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    width: 80,
                    height: 4,
                    child: LinearProgressIndicator(value: best == 0 ? 0 : (s.inHandPerNight ?? 0) / best, backgroundColor: c.surfaceAlt, color: PlatformColors.of(context, s.platform)),
                  ),
                ),
              ]),
            ),
            Expanded(flex: 2, child: Text(pct(s.commissionPct), style: AppText.num(context, size: 14), textAlign: TextAlign.right)),
            Expanded(flex: 2, child: Text('${s.nights}', style: AppText.num(context, size: 14), textAlign: TextAlign.right)),
          ]),
        ),
      ],
    ]);
  }
}

class _WeekdayChart extends StatelessWidget {
  final List<WeekdayStats> days;
  const _WeekdayChart(this.days);
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (days.every((d) => d.nights == 0)) return const _NoData();
    final maxN = days.map((d) => d.nights).reduce(math.max).toDouble();
    final bestRate = days.map((d) => d.perNight ?? 0).reduce(math.max);
    return Column(children: [
      SizedBox(
        height: 150,
        child: BarChart(
          BarChartData(
            maxY: maxN * 1.15,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: _titles(context, WeekdayStats.names),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => c.ink,
                tooltipBorderRadius: BorderRadius.circular(10),
                getTooltipItem: (g, _, rod, __) => BarTooltipItem(
                  '${days[g.x].name}: ${days[g.x].nights} nights · ${pct(days[g.x].occupancy)}',
                  AppText.label(context).copyWith(color: c.background, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            barGroups: [
              for (final d in days)
                BarChartGroupData(x: d.index, barRods: [
                  BarChartRodData(
                    toY: d.nights.toDouble(),
                    width: 22,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    color: d.index >= 4 && d.index <= 5 ? c.accent : c.accent.withValues(alpha: 0.45),
                  ),
                ]),
            ],
          ),
        ),
      ),
      const SizedBox(height: Space.md),
      Row(children: [
        for (final d in days)
          Expanded(
            child: Column(children: [
              Text(d.perNight == null ? '—' : inrCompact(d.perNight!),
                  style: AppText.num(context, size: 11.5).copyWith(color: d.perNight == bestRate && bestRate > 0 ? c.positive : c.inkSoft, fontWeight: FontWeight.w600)),
              Text('/night', style: AppText.label(context).copyWith(fontSize: 9.5)),
            ]),
          ),
      ]),
    ]);
  }
}

class _LeadTimes extends StatelessWidget {
  final Map<String, LeadTimeStats> lt;
  const _LeadTimes(this.lt);
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final list = lt.values.where((s) => s.days.isNotEmpty).toList()..sort((a, b) => b.average.compareTo(a.average));
    if (list.isEmpty) return const _NoData();
    final maxAvg = list.map((s) => s.average).reduce(math.max);
    final hist = [0, 0, 0, 0];
    for (final s in list) {
      final h = s.histogram;
      for (var i = 0; i < 4; i++) {
        hist[i] += h[i];
      }
    }
    final totalH = hist.reduce((a, b) => a + b);
    return Column(children: [
      for (final s in list)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(width: 96, child: Row(children: [PlatformDot(s.platform), const SizedBox(width: 8), Flexible(child: Text(s.platform, style: AppText.label(context).copyWith(color: c.inkSoft), overflow: TextOverflow.ellipsis))])),
            Expanded(
              child: LayoutBuilder(
                builder: (_, box) => Align(
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: maxAvg == 0 ? 0 : s.average / maxAvg),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => Container(
                      height: 10,
                      width: math.max(6, box.maxWidth * v),
                      decoration: BoxDecoration(color: PlatformColors.of(context, s.platform).withValues(alpha: 0.8), borderRadius: BorderRadius.circular(5)),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 64, child: Text('${s.average.round()} days', style: AppText.num(context, size: 12.5), textAlign: TextAlign.right)),
          ]),
        ),
      const SizedBox(height: Space.lg),
      Row(children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: Column(children: [
              Text(totalH == 0 ? '—' : '${(100 * hist[i] / totalH).round()}%', style: AppText.money(context, size: 15)),
              Text(LeadTimeStats.histogramLabels[i], style: AppText.label(context).copyWith(fontSize: 11)),
            ]),
          ),
      ]),
    ]);
  }
}

class _YearHeatmap extends StatelessWidget {
  final Map<DateTime, double> days;
  const _YearHeatmap(this.days);
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final keys = days.keys.toList()..sort();
    if (keys.isEmpty) return const _NoData();
    final start = startOfWeek(keys.first);
    final weeks = (daysBetween(start, keys.last) ~/ 7) + 1;
    final t = today();
    return LayoutBuilder(builder: (context, box) {
      const gap = 3.0;
      final cell = math.min(16.0, (box.maxWidth - 28 - gap * weeks) / weeks);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              const SizedBox(height: 16),
              for (var r = 0; r < 7; r++)
                SizedBox(height: math.max(cell, 9) + gap, width: 26, child: Text(r % 2 == 0 ? WeekdayStats.names[r] : '', style: AppText.label(context).copyWith(fontSize: 9.5))),
            ]),
            for (var w = 0; w < weeks; w++)
              Padding(
                padding: const EdgeInsets.only(right: gap),
                child: Column(children: [
                  SizedBox(
                    height: 16,
                    width: math.max(cell, 9),
                    child: Builder(builder: (_) {
                      final d = addDays(start, w * 7);
                      final firstOfMonth = d.day <= 7;
                      return firstOfMonth ? OverflowBox(maxWidth: 40, alignment: Alignment.topLeft, child: Text(DateFormat('MMM').format(addDays(d, 6)), style: AppText.label(context).copyWith(fontSize: 9.5))) : const SizedBox();
                    }),
                  ),
                  for (var r = 0; r < 7; r++)
                    Builder(builder: (_) {
                      final d = addDays(start, w * 7 + r);
                      final v = days[d];
                      Color color;
                      if (v == null) {
                        color = Colors.transparent;
                      } else if (v < 0) {
                        color = c.muted.withValues(alpha: 0.3);
                      } else if (v == 0) {
                        color = c.surfaceAlt;
                      } else {
                        color = Color.lerp(c.accent.withValues(alpha: 0.35), c.accent, v.clamp(0, 1))!;
                      }
                      return Tooltip(
                        message: v == null ? '' : '${fmtDate(d)} · ${v < 0 ? 'blocked' : (v == 0 ? 'free' : 'booked')}',
                        child: Container(
                          width: math.max(cell, 9),
                          height: math.max(cell, 9),
                          margin: const EdgeInsets.only(bottom: gap),
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3), border: d == t ? Border.all(color: c.ink, width: 1.2) : null),
                        ),
                      );
                    }),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: Space.md),
        Row(children: [
          Text('Free', style: AppText.label(context).copyWith(fontSize: 11)),
          const SizedBox(width: 6),
          for (final a in [0.0, 0.35, 0.65, 1.0])
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(color: a == 0 ? c.surfaceAlt : Color.lerp(c.accent.withValues(alpha: 0.35), c.accent, a), borderRadius: BorderRadius.circular(3)),
            ),
          const SizedBox(width: 3),
          Text('Booked', style: AppText.label(context).copyWith(fontSize: 11)),
          const SizedBox(width: 14),
          Container(width: 12, height: 12, decoration: BoxDecoration(color: c.muted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text('Blocked', style: AppText.label(context).copyWith(fontSize: 11)),
        ]),
      ]);
    });
  }
}

class _ForwardLook extends StatelessWidget {
  final InsightsData data;
  const _ForwardLook(this.data);
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = today();
    final looks = [for (final d in [30, 60, 90]) data.forward(t, d)];
    final gaps = looks.last.gaps.where((g) => g.start.isBefore(addDays(t, 60))).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TileGrid(phoneColumns: 3, wideColumns: 3, children: [
        for (final f in looks)
          AppCard(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('NEXT ${f.days} DAYS', style: AppText.overline(context).copyWith(fontSize: 10)),
              const SizedBox(height: Space.sm),
              FittedBox(fit: BoxFit.scaleDown, child: Text(pct(f.occupancy), style: AppText.money(context, size: 24))),
              Text('${f.nightsBooked} of ${f.nightsAvailable} nights', style: AppText.label(context).copyWith(fontSize: 11.5)),
              const SizedBox(height: Space.sm),
              FittedBox(fit: BoxFit.scaleDown, child: Text(inr(f.expectedGuestPaid), style: AppText.money(context, size: 14.5).copyWith(color: c.accent))),
              Text('on the books', style: AppText.label(context).copyWith(fontSize: 11)),
            ]),
          ),
      ]),
      const SizedBox(height: Space.md),
      AppCard(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Empty nights · next 60 days', style: AppText.title(context)),
          const SizedBox(height: Space.sm),
          if (gaps.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: Space.md), child: Text('Fully booked. Nice.', style: AppText.body(context).copyWith(color: c.muted))),
          for (final g in gaps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Container(width: 4, height: 30, decoration: BoxDecoration(color: g.nights >= 3 ? c.warning : c.hairline, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${DateFormat('EEE d MMM').format(g.start)} → ${DateFormat('EEE d MMM').format(g.end)}', style: AppText.body(context).copyWith(color: c.ink)),
                    if (data.properties.length > 1) Text(g.property, style: AppText.label(context)),
                  ]),
                ),
                Pill(plural(g.nights, 'night'), color: g.nights >= 3 ? c.warning : c.muted, background: g.nights >= 3 ? c.warning.withValues(alpha: 0.12) : null),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

class _NoData extends StatelessWidget {
  const _NoData();
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 120,
        child: Center(child: Text('Not enough data for this period', style: AppText.label(context))),
      );
}
