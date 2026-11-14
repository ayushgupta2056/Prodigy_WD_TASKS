import 'package:material_ui/material_ui.dart';
import '../../theme/icons.dart';

import '../../core/dates.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../theme/app_theme.dart';
import '../app_scope.dart';
import '../screens/booking_detail_screen.dart';
import 'common.dart';

void openBooking(BuildContext context, String id) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: id)));

/// One booking as a row: platform dot, guest, dates, amount.
class BookingTile extends StatelessWidget {
  final Booking b;
  final bool showStatus;
  final String? caption;
  const BookingTile(this.b, {super.key, this.showStatus = true, this.caption});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final f = Financials.ofBooking(b);
    final overlap = context.repo.overlapIds.contains(b.id);
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.field),
      onTap: () => openBooking(context, b.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md, horizontal: Space.xs),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: overlap ? c.dangerSoft : PlatformColors.of(context, b.platform).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: overlap
                ? Icon(LucideIcons500.triangleAlert, color: c.danger, size: 18)
                : Text(b.guestName.trim().isEmpty ? '?' : firstName(b.guestName)[0].toUpperCase(),
                    style: AppText.title(context).copyWith(color: PlatformColors.of(context, b.platform))),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(b.guestName.isEmpty ? 'Guest' : b.guestName,
                      style: AppText.title(context).copyWith(decoration: b.isCancelled ? TextDecoration.lineThrough : null, color: b.isCancelled ? c.muted : null),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                PlatformDot(b.platform, size: 7),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(caption ?? '${b.platform} · ${fmtRange(b.checkIn, b.checkOut)} · ${plural(b.nights, 'night')}',
                      style: AppText.label(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: Space.md),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(inr(f.inHand ?? f.guestPaid), style: AppText.money(context, size: 15.5).copyWith(color: b.isCancelled ? c.muted : null)),
            const SizedBox(height: 3),
            if (showStatus && b.isCancelled)
              const StatusPill('cancelled')
            else if (b.isActive && f.pending && b.checkIn.isAfter(today()))
              Text('guest paid', style: AppText.label(context).copyWith(fontSize: 11.5))
            else if (b.isActive && f.pending)
              Text('in hand pending', style: AppText.label(context).copyWith(color: c.warning, fontSize: 11.5))
            else if (f.cutPct != null)
              Text('${pct(f.cutPct)} cut', style: AppText.label(context).copyWith(fontSize: 11.5))
            else
              Text(b.platform == 'Direct' ? 'direct' : '', style: AppText.label(context).copyWith(fontSize: 11.5)),
          ]),
        ]),
      ),
    );
  }
}

/// "Synced 2 min ago" / "Offline · 2 changes waiting" + refresh button.
class SyncStatus extends StatelessWidget {
  final bool showButton;
  const SyncStatus({super.key, this.showButton = true});

  @override
  Widget build(BuildContext context) {
    final repo = context.repo;
    final c = context.colors;
    String text;
    Color color = c.muted;
    IconData icon = LucideIcons300.cloudCheck;
    if (repo.syncing) {
      text = 'Syncing…';
      icon = LucideIcons300.refreshCw;
    } else if (repo.lastError != null) {
      text = repo.pendingOps.isEmpty ? 'Offline' : 'Offline · ${plural(repo.pendingOps.length, 'change')} waiting';
      color = c.warning;
      icon = LucideIcons300.cloudOff;
    } else if (repo.pendingOps.isNotEmpty) {
      text = '${plural(repo.pendingOps.length, 'change')} waiting';
      icon = LucideIcons300.cloudUpload;
    } else {
      text = repo.lastSyncAt == null ? 'Not synced yet' : 'Synced ${_ago(repo.lastSyncAt!)}';
    }
    if (repo.mode.name == 'demo') text = 'Demo data · $text';
    final local = repo.mode.name == 'local';
    if (local) {
      text = 'Saved on this device';
      icon = LucideIcons300.hardDrive;
      color = c.muted;
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 5),
      Text(text, style: AppText.label(context).copyWith(color: color)),
      if (showButton && !local) ...[
        const SizedBox(width: 2),
        IconButton(
          tooltip: 'Sync now',
          visualDensity: VisualDensity.compact,
          onPressed: repo.syncing ? null : () => repo.sync(checkEmails: true),
          icon: Icon(LucideIcons300.rotateCw, size: 18, color: c.inkSoft),
        ),
      ],
    ]);
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return fmtDate(DateTime.utc(t.year, t.month, t.day));
  }
}

/// Red double-booking banner.
class OverlapBanner extends StatelessWidget {
  final VoidCallback? onTap;
  const OverlapBanner({super.key, this.onTap});
  @override
  Widget build(BuildContext context) {
    final repo = context.repo;
    final c = context.colors;
    if (repo.overlaps.isEmpty) return const SizedBox.shrink();
    final o = repo.overlaps.first;
    String name(String id) => repo.booking(id)?.guestName ?? 'Blocked dates';
    final more = repo.overlaps.length > 1 ? ' (+${repo.overlaps.length - 1} more)' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: AppCard(
        color: c.dangerSoft,
        borderColor: c.danger.withValues(alpha: 0.35),
        padding: const EdgeInsets.all(Space.lg),
        onTap: onTap,
        child: Row(children: [
          Icon(LucideIcons500.octagonAlert, color: c.danger, size: 24),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Possible double booking', style: AppText.title(context).copyWith(color: c.danger)),
              const SizedBox(height: 2),
              Text('${name(o.aId)} and ${name(o.bId)} overlap on ${fmtRange(o.start, o.end)}$more.',
                  style: AppText.label(context).copyWith(color: c.inkSoft)),
            ]),
          ),
          Icon(LucideIcons300.chevronRight, color: c.danger, size: 18),
        ]),
      ),
    );
  }
}

/// Errors from ops the server rejected.
class OpErrorBanner extends StatelessWidget {
  const OpErrorBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = context.repo;
    if (repo.opErrors.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: AppCard(
        color: context.colors.dangerSoft,
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.xs, Space.sm),
        child: Row(children: [
          Expanded(child: Text('Not saved: ${repo.opErrors.last}', style: AppText.label(context).copyWith(color: context.colors.danger))),
          IconButton(onPressed: repo.clearOpErrors, icon: const Icon(LucideIcons300.x, size: 16)),
        ]),
      ),
    );
  }
}
