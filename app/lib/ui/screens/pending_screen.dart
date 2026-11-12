import 'package:material_ui/material_ui.dart';
import '../../theme/icons.dart';

import '../../core/dates.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../theme/app_theme.dart';
import '../app_scope.dart';
import '../widgets/common.dart';

/// "How much did you get in hand?" for every stay that has started and has
/// no in-hand amount yet.
class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key});
  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  final _skipped = <String>{};

  @override
  Widget build(BuildContext context) {
    final repo = context.repo;
    final all = repo.pendingInHand;
    final list = [...all.where((b) => !_skipped.contains(b.id)), ...all.where((b) => _skipped.contains(b.id))];
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(title: const Text('Pending in-hand'), automaticallyImplyLeading: canPop),
      body: list.isEmpty
          ? const EmptyState(
              icon: LucideIcons300.circleCheck,
              title: 'All caught up',
              message: 'Every stay that has started has its in-hand amount. New ones appear here after check-in.',
            )
          : PageBody(maxWidth: 720, onRefresh: () => repo.sync(), children: [
              Text('${plural(list.length, 'stay')} waiting. Amounts are for the whole stay, after the platform’s cut.', style: AppText.label(context)),
              const SizedBox(height: Space.lg),
              for (var i = 0; i < list.length; i++)
                Padding(
                  key: ValueKey(list[i].id),
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: EaseIn(
                    index: i,
                    child: InHandCard(
                      booking: list[i],
                      skipped: _skipped.contains(list[i].id),
                      onSkip: () => setState(() => _skipped.add(list[i].id)),
                    ),
                  ),
                ),
            ]),
    );
  }
}

/// Opens the same prompt as a sheet (from a booking or a notification).
Future<void> showInHandSheet(BuildContext context, Booking b) => showAdaptiveSheet<void>(
      context,
      builder: (ctx) => SingleChildScrollView(child: InHandCard(booking: b, inSheet: true, onSkip: () => Navigator.pop(ctx))),
    );

class InHandCard extends StatefulWidget {
  final Booking booking;
  final VoidCallback onSkip;
  final bool skipped;
  final bool inSheet;
  const InHandCard({super.key, required this.booking, required this.onSkip, this.skipped = false, this.inSheet = false});
  @override
  State<InHandCard> createState() => _InHandCardState();
}

class _InHandCardState extends State<InHandCard> {
  final _inHand = TextEditingController();
  late final _costs = TextEditingController(text: widget.booking.costs == 0 ? '' : widget.booking.costs.round().toString());

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final c = context.colors;
    final inHand = parseAmountInput(_inHand.text);
    final f = Financials.of(nights: b.nights, guestPaid: b.guestTotalPaid, inHand: inHand, costs: parseAmountInput(_costs.text) ?? 0);
    final checkedOut = !b.checkOut.isAfter(today());

    final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        PlatformDot(b.platform, size: 9),
        const SizedBox(width: 8),
        Expanded(
          child: Text('${shortName(b.guestName)} · ${b.platform} · ${plural(b.nights, 'night')} (${fmtRange(b.checkIn, b.checkOut)})',
              style: AppText.title(context), maxLines: 2),
        ),
        if (widget.skipped) Pill('Skipped', color: c.muted),
      ]),
      const SizedBox(height: Space.md),
      Row(children: [
        Text('Guest paid', style: AppText.body(context).copyWith(color: c.muted)),
        const SizedBox(width: 8),
        Text(inr(b.guestTotalPaid), style: AppText.money(context, size: 16)),
        const Spacer(),
        if (!checkedOut) Pill('In house', color: c.accent, background: c.accentSoft),
      ]),
      const SizedBox(height: Space.lg),
      Text('How much did you receive in hand for ${b.nights == 1 ? 'this night' : 'these ${b.nights} nights'}?', style: AppText.body(context).copyWith(color: c.ink)),
      const SizedBox(height: Space.md),
      AmountField(controller: _inHand, label: 'In hand', large: true, autofocus: widget.inSheet, onChanged: (_) => setState(() {})),
      const SizedBox(height: Space.md),
      AmountField(controller: _costs, label: 'Optional: costs for this stay', hint: 'Cleaning, laundry, supplies…', onChanged: (_) => setState(() {})),
      AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: inHand == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: Space.lg),
                child: Container(
                  padding: const EdgeInsets.all(Space.lg),
                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(Radii.field)),
                  child: Wrap(spacing: Space.xxl, runSpacing: Space.md, children: [
                    _Result('In hand', inr(f.inHand)),
                    _Result('Per night', inr(f.perNight)),
                    _Result('Platform cut', f.cut == null ? '—' : '${inr(f.cut)} · ${pct(f.cutPct, decimals: 1)}', color: (f.cut ?? 0) < 0 ? c.warning : null),
                    _Result('Profit', inr(f.profit), color: c.positive),
                  ]),
                ),
              ),
      ),
      if (inHand != null && b.guestTotalPaid != null && inHand > b.guestTotalPaid!)
        Padding(
          padding: const EdgeInsets.only(top: Space.sm),
          child: Text('That is more than the guest paid. Double-check the amount.', style: AppText.label(context).copyWith(color: c.warning)),
        ),
      const SizedBox(height: Space.lg),
      Row(children: [
        TextButton(onPressed: widget.onSkip, child: const Text('Skip for now')),
        const Spacer(),
        FilledButton(
          onPressed: inHand == null
              ? null
              : () async {
                  final repo = context.repoRead;
                  await repo.setInHand(b, inHand, parseAmountInput(_costs.text) ?? 0);
                  if (!context.mounted) return;
                  savedFeedback(context, 'Saved: ${inr(inHand)} in hand, ${inr(f.profit)} profit');
                  if (widget.inSheet) Navigator.pop(context);
                },
          child: const Text('Save'),
        ),
      ]),
    ]);
    return widget.inSheet ? content : AppCard(child: content);
  }
}

class _Result extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Result(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: AppText.label(context)),
        const SizedBox(height: 2),
        Text(value, style: AppText.money(context, size: 17).copyWith(color: color)),
      ]);
}
