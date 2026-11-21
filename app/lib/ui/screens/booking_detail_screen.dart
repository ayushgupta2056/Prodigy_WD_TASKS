import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import '../../theme/icons.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../../theme/app_theme.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import 'booking_form.dart';
import 'pending_screen.dart';

class BookingDetailScreen extends StatelessWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    final repo = context.repo;
    final b = repo.booking(bookingId);
    final c = context.colors;
    if (b == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: LucideIcons300.trash2, title: 'This booking was deleted'));
    }
    final f = Financials.ofBooking(b);
    final overlap = repo.overlapIds.contains(b.id);
    bool ed(String field) => b.editedFields.contains(field);

    Widget row(String label, String value, {String? field, Color? color, bool money = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            Expanded(child: Row(children: [Text(label, style: AppText.body(context).copyWith(color: c.muted)), if (field != null && ed(field)) const EditedBadge()])),
            Text(value, style: money ? AppText.money(context, size: 15.5).copyWith(color: color) : AppText.title(context).copyWith(color: color, fontWeight: FontWeight.w500)),
          ]),
        );

    final money = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('IN HAND', style: AppText.overline(context)),
        const SizedBox(height: Space.sm),
        if (f.pending)
          Row(children: [
            Text('Not entered yet', style: AppText.display(context).copyWith(color: c.muted, fontSize: 24)),
            const Spacer(),
            if (b.isActive)
              FilledButton.tonal(
                onPressed: () => showInHandSheet(context, b),
                child: const Text('Enter amount'),
              ),
          ])
        else
          CountUp(value: f.inHand!, format: (v) => inr(v), style: AppText.display(context)),
        const SizedBox(height: Space.lg),
        const Divider(),
        const SizedBox(height: Space.sm),
        row('Guest paid', inr(b.guestTotalPaid), field: 'guest_total_paid', money: true),
        row('Platform cut', f.cut == null ? '—' : '${inr(f.cut)}  ·  ${pct(f.cutPct, decimals: 1)}', money: true),
        row('Costs for this stay', inr(b.costs), money: true),
        row('Profit', inr(f.profit), color: f.profit == null ? null : c.positive, money: true),
        row('In hand per night', inr(f.perNight), money: true),
      ]),
    );

    final details = AppCard(
      child: Column(children: [
        row('Check-in', DateFormat('EEE, d MMM yyyy').format(b.checkIn), field: 'check_in'),
        row('Check-out', DateFormat('EEE, d MMM yyyy').format(b.checkOut), field: 'check_out'),
        row('Nights', '${b.nights}'),
        row('Guests', b.guestsCount?.toString() ?? '—', field: 'guests_count'),
        if (repo.properties.length > 1) row('Property', b.property.isEmpty ? repo.defaultProperty : b.property, field: 'property'),
        row('Booking ID', b.platformBookingId.isEmpty ? '—' : b.platformBookingId, field: 'platform_booking_id'),
        row('Source', b.isEmail ? 'Email' : 'Added by you'),
        if (b.notes.isNotEmpty) ...[
          const Divider(),
          Padding(padding: const EdgeInsets.only(top: Space.md), child: Align(alignment: Alignment.centerLeft, child: Text(b.notes, style: AppText.body(context)))),
        ],
      ]),
    );

    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(tooltip: 'Edit', onPressed: () => showBookingForm(context, existing: b), icon: const Icon(LucideIcons300.pencil)),
        PopupMenuButton<String>(
          icon: const Icon(LucideIcons300.ellipsisVertical),
          onSelected: (v) async {
            final r = context.repoRead;
            if (v == 'cancel' && await _confirm(context, 'Mark as cancelled?', 'The dates become free again. You can change the status back later.')) {
              await r.cancelBooking(b.id);
              if (context.mounted) savedFeedback(context, 'Marked as cancelled');
            }
            if (v == 'delete' && context.mounted && await _confirm(context, 'Delete this booking?', 'This removes it completely.')) {
              await r.deleteBooking(b.id);
              if (context.mounted) Navigator.pop(context);
            }
          },
          itemBuilder: (_) => [
            if (!b.isCancelled) const PopupMenuItem(value: 'cancel', child: Text('Mark as cancelled')),
            if (!b.isEmail) const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ]),
      body: PageBody(maxWidth: 760, children: [
        Row(children: [
          PlatformDot(b.platform, size: 10),
          const SizedBox(width: 8),
          Text(b.platform, style: AppText.label(context).copyWith(fontSize: 13.5)),
          const SizedBox(width: 10),
          StatusPill(b.status),
        ]),
        const SizedBox(height: Space.sm),
        Row(children: [
          Flexible(child: Text(b.guestName.isEmpty ? 'Guest' : b.guestName, style: AppText.h1(context))),
          if (ed('guest_name')) const EditedBadge(),
        ]),
        const SizedBox(height: 4),
        Text('${fmtRange(b.checkIn, b.checkOut)} ${b.checkIn.year} · ${plural(b.nights, 'night')}', style: AppText.body(context).copyWith(color: c.muted)),
        const SizedBox(height: Space.xl),
        if (overlap)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.lg),
            child: AppCard(
              color: c.dangerSoft,
              borderColor: c.danger.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(Space.lg),
              child: Row(children: [
                Icon(LucideIcons500.octagonAlert, color: c.danger),
                const SizedBox(width: Space.md),
                Expanded(child: Text('These dates overlap another booking or block.', style: AppText.body(context).copyWith(color: c.danger))),
              ]),
            ),
          ),
        if (context.isWide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: money), const SizedBox(width: Space.lg), Expanded(child: details)])
        else ...[money, const SizedBox(height: Space.md), details],
      ]),
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: AppText.h2(ctx)),
        content: Text(body, style: AppText.body(ctx)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    ) ??
    false;
