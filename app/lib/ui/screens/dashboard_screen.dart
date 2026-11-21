import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import '../../theme/icons.dart';

import '../../core/dates.dart';
import '../../core/format.dart';
import '../../core/insights.dart';
import '../../theme/app_theme.dart';
import '../app_scope.dart';
import '../shell.dart';
import '../widgets/booking_widgets.dart';
import '../widgets/common.dart';
import 'pending_screen.dart';
import 'unparsed_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.repo;
    final c = context.colors;
    final t = today();
    final data = repo.insights();
    final month = Period.containing(PeriodKind.month, t);
    final m = data.forPeriod(month);
    final prev = data.forPeriod(month.previous);
    final bookings = repo.view.bookings;

    if (!repo.loaded || (repo.syncing && bookings.isEmpty)) return const _DashboardSkeleton();

    final checkIns = bookings.where((b) => b.isActive && b.checkIn == t).toList();
    final checkOuts = bookings.where((b) => b.isActive && b.checkOut == t).toList();
    final inHouse = bookings.where((b) => b.isActive && b.checkIn.isBefore(t) && b.checkOut.isAfter(t)).toList();
    final upcoming = bookings.where((b) => b.isActive && b.checkIn.isAfter(t)).toList()..sort((a, b) => a.checkIn.compareTo(b.checkIn));
    final cards = generateInsights(data, month, t);
    final waiting = repo.pendingInHand.where((b) => month.contains(b.checkIn)).length;
    final wide = context.isWide;

    final hero = EaseIn(
      child: AppCard(
        padding: const EdgeInsets.all(Space.xxl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('IN HAND · ${DateFormat('MMMM').format(month.start).toUpperCase()}', style: AppText.overline(context)),
            const Spacer(),
            DeltaChip(pctChange(m.inHand, prev.inHand), suffix: 'vs last month'),
          ]),
          const SizedBox(height: Space.md),
          CountUp(value: m.inHand, format: (v) => inr(v), style: AppText.hero(context)),
          if (waiting > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('+ ${plural(waiting, 'stay')} waiting for an in-hand amount', style: AppText.label(context).copyWith(color: c.warning)),
            ),
          const SizedBox(height: Space.xxl),
          Wrap(spacing: Space.xxxl, runSpacing: Space.lg, children: [
            _MiniStat('Guest paid', inr(m.guestPaid)),
            _MiniStat('Platform cut', '${inr(m.cut)}  ·  ${pct(m.cutPct)}'),
            _MiniStat('Profit', inr(m.profit), color: c.positive),
            _MiniStat('Occupancy', pct(m.occupancy), trailing: _Ring(value: (m.occupancy ?? 0) / 100)),
          ]),
        ]),
      ),
    );

    final queue = Row(children: [
      Expanded(
        child: EaseIn(
          index: 1,
          child: _QueueCard(
            icon: LucideIcons300.handCoins,
            count: repo.pendingInHand.length,
            title: 'Pending in-hand',
            subtitle: repo.pendingInHand.isEmpty ? 'All amounts entered' : 'Tap to add amounts',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PendingScreen())),
          ),
        ),
      ),
      const SizedBox(width: Space.md),
      Expanded(
        child: EaseIn(
          index: 2,
          child: _QueueCard(
            icon: LucideIcons300.mail,
            count: repo.view.unparsed.length,
            title: 'Unparsed emails',
            subtitle: repo.view.unparsed.isEmpty ? 'Nothing to review' : 'Need a quick look',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UnparsedScreen())),
          ),
        ),
      ),
    ]);

    final todayCard = EaseIn(
      index: 3,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Today · ${DateFormat('EEE d MMM').format(t)}', style: AppText.title(context)),
          const SizedBox(height: Space.sm),
          if (checkIns.isEmpty && checkOuts.isEmpty && inHouse.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.lg),
              child: Row(children: [
                Icon(LucideIcons300.sun, color: c.muted, size: 18),
                const SizedBox(width: 8),
                Text('No arrivals or departures today', style: AppText.body(context).copyWith(color: c.muted)),
              ]),
            ),
          for (final b in checkIns) BookingTile(b, caption: 'Checking in · ${b.platform} · ${plural(b.nights, 'night')}'),
          for (final b in checkOuts) BookingTile(b, caption: 'Checking out · ${b.platform}'),
          for (final b in inHouse) BookingTile(b, caption: 'Staying until ${fmtDayMonth(b.checkOut)} · ${b.platform}'),
        ]),
      ),
    );

    final upcomingCard = EaseIn(
      index: 4,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Upcoming stays', style: AppText.title(context)),
            const Spacer(),
            TextButton(onPressed: () => Shell.goTo(context, 'Calendar'), child: const Text('Calendar')),
          ]),
          if (upcoming.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: Space.lg), child: Text('No upcoming stays yet.', style: AppText.body(context).copyWith(color: c.muted))),
          for (final b in upcoming.take(5)) BookingTile(b, caption: '${_inDays(b.checkIn, t)} · ${b.platform} · ${plural(b.nights, 'night')}'),
        ]),
      ),
    );

    final insight = cards.where((x) => x.kind != 'pending').isEmpty
        ? null
        : EaseIn(index: 5, child: _InsightTeaser(cards.firstWhere((x) => x.kind != 'pending')));

    return Scaffold(
      body: SafeArea(
        child: PageBody(
          onRefresh: () => repo.sync(checkEmails: true),
          children: [
            const SizedBox(height: Space.lg),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(greeting(DateTime.now()), style: AppText.label(context)),
                  const SizedBox(height: 2),
                  Text(repo.properties.length == 1 ? repo.properties.first : '${repo.properties.length} properties', style: AppText.h1(context)),
                  if (!wide) const Padding(padding: EdgeInsets.only(top: 4), child: SyncStatus(showButton: false)),
                ]),
              ),
              if (wide) const SyncStatus(),
            ]),
            const SizedBox(height: Space.xl),
            OverlapBanner(onTap: () => Shell.goTo(context, 'Calendar')),
            const OpErrorBanner(),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: Column(children: [hero, const SizedBox(height: Space.lg), queue, if (insight != null) ...[const SizedBox(height: Space.lg), insight]])),
                const SizedBox(width: Space.lg),
                Expanded(flex: 2, child: Column(children: [todayCard, const SizedBox(height: Space.lg), upcomingCard])),
              ])
            else ...[
              hero,
              const SizedBox(height: Space.md),
              queue,
              const SizedBox(height: Space.md),
              todayCard,
              const SizedBox(height: Space.md),
              upcomingCard,
              if (insight != null) ...[const SizedBox(height: Space.md), insight],
            ],
          ],
        ),
      ),
    );
  }

  static String _inDays(DateTime d, DateTime t) {
    final n = daysBetween(t, d);
    if (n == 1) return 'Tomorrow';
    if (n < 7) return 'In $n days';
    return fmtDayMonth(d);
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final Widget? trailing;
  const _MiniStat(this.label, this.value, {this.color, this.trailing});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (trailing != null) ...[trailing!, const SizedBox(width: 10)],
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppText.label(context)),
          const SizedBox(height: 3),
          Text(value, style: AppText.money(context, size: 16.5).copyWith(color: color)),
        ]),
      ]);
}

class _Ring extends StatelessWidget {
  final double value;
  const _Ring({required this.value});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            value: v,
            strokeWidth: 3.5,
            strokeCap: StrokeCap.round,
            backgroundColor: context.colors.surfaceAlt,
            color: context.colors.accent,
          ),
        ),
      );
}

class _QueueCard extends StatelessWidget {
  final IconData icon;
  final int count;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _QueueCard({required this.icon, required this.count, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = count > 0;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: active ? c.warning.withValues(alpha: 0.13) : c.surfaceAlt, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 19, color: active ? c.warning : c.muted),
          ),
          const Spacer(),
          CountUp(value: count.toDouble(), format: (v) => '${v.round()}', style: AppText.money(context, size: 24).copyWith(color: active ? c.ink : c.muted)),
        ]),
        const SizedBox(height: Space.md),
        Text(title, style: AppText.title(context), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(subtitle, style: AppText.label(context), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _InsightTeaser extends StatelessWidget {
  final InsightCard card;
  const _InsightTeaser(this.card);
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      color: c.accentSoft,
      borderColor: Colors.transparent,
      onTap: () => Shell.goTo(context, 'Insights'),
      child: Row(children: [
        Icon(LucideIcons300.lightbulb, color: c.accent, size: 22),
        const SizedBox(width: Space.md),
        Expanded(child: Text(card.text, style: AppText.body(context).copyWith(color: c.ink))),
        Icon(LucideIcons300.chevronRight, color: c.accent, size: 16),
      ]),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: SafeArea(
          child: PageBody(children: [
            SizedBox(height: Space.xl),
            Skeleton(width: 120, height: 12),
            SizedBox(height: Space.sm),
            Skeleton(width: 220, height: 26),
            SizedBox(height: Space.xxl),
            Skeleton(height: 210, radius: Radii.card),
            SizedBox(height: Space.md),
            Row(children: [Expanded(child: Skeleton(height: 120, radius: Radii.card)), SizedBox(width: Space.md), Expanded(child: Skeleton(height: 120, radius: Radii.card))]),
            SizedBox(height: Space.md),
            Skeleton(height: 180, radius: Radii.card),
          ]),
        ),
      );
}

