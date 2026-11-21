import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import '../../theme/icons.dart';

import '../../core/dates.dart';
import '../../core/format.dart';
import '../../core/insights.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../theme/app_theme.dart';
import '../app_scope.dart';
import '../export_actions.dart';
import '../widgets/booking_widgets.dart';
import '../widgets/common.dart';
import 'booking_form.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final _search = TextEditingController();
  final _platforms = <String>{};
  String _status = 'all';
  DateTime? _month; // null = all months

  List<Booking> _filtered(List<Booking> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((b) {
      if (_platforms.isNotEmpty && !_platforms.contains(b.platform)) return false;
      if (_status != 'all' && b.status != _status) return false;
      if (_month != null && overlapNights(b.checkIn, b.checkOut, _month!, addMonths(_month!, 1)) == 0 && !(b.checkIn.year == _month!.year && b.checkIn.month == _month!.month)) return false;
      if (q.isNotEmpty && !('${b.guestName} ${b.platformBookingId} ${b.notes} ${b.platform}'.toLowerCase().contains(q))) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.checkIn.compareTo(a.checkIn));
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.repo;
    final c = context.colors;
    final all = repo.view.bookings;
    final list = _filtered(all);
    final months = {for (final b in all) startOfMonth(b.checkIn)}.toList()..sort((a, b) => b.compareTo(a));
    final active = list.where((b) => b.isActive);
    final totalPaid = active.fold<double>(0, (a, b) => a + (b.guestTotalPaid ?? 0));
    final totalInHand = active.fold<double>(0, (a, b) => a + (b.inHandAmount ?? 0));
    final totalProfit = active.fold<double>(0, (a, b) => a + (Financials.ofBooking(b).profit ?? 0));

    // Group by check-in month.
    final groups = <DateTime, List<Booking>>{};
    for (final b in list) {
      groups.putIfAbsent(startOfMonth(b.checkIn), () => []).add(b);
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'list-fab',
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        elevation: 2,
        onPressed: () => showBookingForm(context),
        icon: const Icon(LucideIcons300.plus),
        label: const Text('Booking'),
      ),
      body: SafeArea(
        child: PageBody(
          maxWidth: 900,
          onRefresh: () => repo.sync(checkEmails: true),
          children: [
            const SizedBox(height: Space.lg),
            Row(children: [
              Expanded(child: Text('Bookings', style: AppText.h1(context))),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: () => exportToExcel(
                  context,
                  filtered: list,
                  period: _month == null ? null : Period.containing(PeriodKind.month, _month!),
                  scopeLabel: 'These ${plural(list.length, 'booking')}',
                ),
                icon: const Icon(LucideIcons300.fileSpreadsheet, size: 18),
                label: const Text('Export'),
              ),
            ]),
            const SizedBox(height: Space.lg),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search guest, booking ID, notes',
                prefixIcon: const Icon(LucideIcons300.search, size: 18),
                suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(LucideIcons300.x, size: 16), onPressed: () => setState(_search.clear)),
              ),
            ),
            const SizedBox(height: Space.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _MonthMenu(months: months, value: _month, onChanged: (m) => setState(() => _month = m)),
                const SizedBox(width: 8),
                _StatusMenu(value: _status, onChanged: (s) => setState(() => _status = s)),
                const SizedBox(width: 8),
                for (final p in platforms)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterPill(
                      leading: PlatformDot(p),
                      label: p,
                      active: _platforms.contains(p),
                      onTap: () => setState(() => _platforms.contains(p) ? _platforms.remove(p) : _platforms.add(p)),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: Space.lg),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
              child: Row(children: [
                _Total('Bookings', '${list.length}'),
                _Total('Guest paid', inr(totalPaid)),
                _Total('In hand', inr(totalInHand)),
                _Total('Profit', inr(totalProfit), color: c.positive),
              ]),
            ),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: Space.xxxl),
                child: EmptyState(icon: LucideIcons300.search, title: 'No bookings match', message: 'Try clearing a filter.'),
              ),
            for (final g in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: Space.xl, bottom: Space.xs, left: Space.xs),
                child: Text(DateFormat('MMMM yyyy').format(g.key).toUpperCase(), style: AppText.overline(context)),
              ),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
                child: Column(children: [
                  for (var i = 0; i < g.value.length; i++) ...[
                    if (i > 0) const Divider(),
                    BookingTile(g.value[i]),
                  ],
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  final String label;
  final String? value;
  final Color? color;
  const _Total(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppText.label(context).copyWith(fontSize: 11.5), maxLines: 1),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value ?? '', style: AppText.money(context, size: 15).copyWith(color: color)),
          ),
        ]),
      );
}

class _MonthMenu extends StatelessWidget {
  final List<DateTime> months;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  const _MonthMenu({required this.months, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => PopupMenuButton<DateTime?>(
        onSelected: onChanged,
        itemBuilder: (_) => [
          const PopupMenuItem(value: null, child: Text('All months')),
          for (final m in months) PopupMenuItem(value: m, child: Text(DateFormat('MMMM yyyy').format(m))),
        ],
        child: FilterPill(icon: LucideIcons300.calendar, label: value == null ? 'All months' : DateFormat('MMM yyyy').format(value!), active: value != null),
      );
}

class _StatusMenu extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _StatusMenu({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        onSelected: onChanged,
        itemBuilder: (_) => [
          for (final s in ['all', ...statuses]) PopupMenuItem(value: s, child: Text(s == 'all' ? 'Any status' : s[0].toUpperCase() + s.substring(1))),
        ],
        child: FilterPill(icon: LucideIcons300.circleDot, label: value == 'all' ? 'Any status' : value[0].toUpperCase() + value.substring(1), active: value != 'all'),
      );
}
