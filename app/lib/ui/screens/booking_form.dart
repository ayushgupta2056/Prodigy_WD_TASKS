import 'package:material_ui/material_ui.dart';
import '../../theme/icons.dart';

import '../../core/dates.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/money.dart';
import '../../theme/app_theme.dart';
import '../app_scope.dart';
import '../widgets/common.dart';

/// Add or edit a booking. Every field is editable; for emailed bookings the
/// fields you change get an "edited" marker and are protected from the parser.
Future<bool?> showBookingForm(
  BuildContext context, {
  Booking? existing,
  DateTime? checkIn,
  DateTime? checkOut,
  String? property,
  UnparsedEmail? fromEmail,
}) =>
    showAdaptiveSheet<bool>(context, maxWidth: 620, builder: (_) => _BookingForm(existing: existing, checkIn: checkIn, checkOut: checkOut, property: property, fromEmail: fromEmail));

class _BookingForm extends StatefulWidget {
  final Booking? existing;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String? property;
  final UnparsedEmail? fromEmail;
  const _BookingForm({this.existing, this.checkIn, this.checkOut, this.property, this.fromEmail});
  @override
  State<_BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends State<_BookingForm> {
  late final repo = context.repoRead;
  late Booking? e = widget.existing;
  late String _platform = e?.platform ?? (widget.fromEmail?.platform.isNotEmpty == true ? widget.fromEmail!.platform : 'Direct');
  late String _property = e?.property.isNotEmpty == true ? e!.property : (widget.property ?? repo.defaultProperty);
  late String _status = e?.status ?? 'confirmed';
  late DateTime _in = e?.checkIn ?? widget.checkIn ?? today();
  late DateTime _out = e?.checkOut ?? widget.checkOut ?? addDays(_in, 1);
  late final _guest = TextEditingController(text: e?.guestName ?? '');
  late final _guests = TextEditingController(text: e?.guestsCount?.toString() ?? '');
  late final _ref = TextEditingController(text: e?.platformBookingId ?? '');
  late final _paid = TextEditingController(text: _amt(e?.guestTotalPaid));
  late final _inHand = TextEditingController(text: _amt(e?.inHandAmount));
  late final _costs = TextEditingController(text: e == null || e!.costs == 0 ? '' : _amt(e!.costs));
  late final _notes = TextEditingController(text: e?.notes ?? (widget.fromEmail != null ? 'From email: ${widget.fromEmail!.subject}' : ''));
  String? _error;

  static String _amt(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2));

  bool _edited(String f) => e?.editedFields.contains(f) ?? false;

  Future<void> _pickDates() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2018),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: DateTime(_in.year, _in.month, _in.day), end: DateTime(_out.year, _out.month, _out.day)),
      helpText: 'Check-in → check-out',
      saveText: 'Done',
    );
    if (r != null) {
      setState(() {
        _in = DateTime.utc(r.start.year, r.start.month, r.start.day);
        _out = DateTime.utc(r.end.year, r.end.month, r.end.day);
        if (!_out.isAfter(_in)) _out = addDays(_in, 1);
      });
    }
  }

  Future<void> _save() async {
    if (_guest.text.trim().isEmpty) return setState(() => _error = 'Add the guest’s name');
    if (!_out.isAfter(_in)) return setState(() => _error = 'Check-out must be after check-in');
    final paid = parseAmountInput(_paid.text), inHand = parseAmountInput(_inHand.text), costs = parseAmountInput(_costs.text) ?? 0;
    final b = Booking(
      id: e?.id ?? repo.newId(),
      property: _property,
      platform: _platform,
      platformBookingId: _ref.text.trim(),
      guestName: _guest.text.trim(),
      guestsCount: int.tryParse(_guests.text.trim()),
      checkIn: _in,
      checkOut: _out,
      guestTotalPaid: paid,
      inHandAmount: inHand,
      costs: costs,
      status: _status,
      source: e?.source ?? 'manual',
      editedFields: e?.editedFields ?? const [],
      emailMessageId: e?.emailMessageId ?? '',
      createdAt: e?.createdAt ?? '',
      notes: _notes.text.trim(),
    );
    await repo.saveBooking(b, emailMessageId: widget.fromEmail?.emailMessageId ?? '');
    if (!mounted) return;
    Navigator.pop(context, true);
    savedFeedback(context, e == null ? 'Booking added' : 'Booking updated');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nights = daysBetween(_in, _out);
    final f = Financials.of(nights: nights < 0 ? 0 : nights, guestPaid: parseAmountInput(_paid.text), inHand: parseAmountInput(_inHand.text), costs: parseAmountInput(_costs.text) ?? 0);
    Widget label(String text, String field) => Row(children: [Text(text), if (_edited(field)) const EditedBadge()]);

    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(e == null ? 'New booking' : 'Edit booking', style: AppText.h2(context)),
        if (e?.isEmail == true)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('From email. Anything you change here is kept, even if a later email says otherwise.', style: AppText.label(context)),
          ),
        const SizedBox(height: Space.xl),
        Text('Platform', style: AppText.label(context)),
        const SizedBox(height: Space.sm),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in platforms)
            ChoiceChip(
              avatar: PlatformDot(p),
              label: Text(p),
              selected: _platform == p,
              onSelected: (_) => setState(() => _platform = p),
            ),
        ]),
        const SizedBox(height: Space.lg),
        if (repo.properties.length > 1) ...[
          DropdownButtonFormField<String>(
            initialValue: repo.properties.contains(_property) ? _property : repo.properties.first,
            decoration: InputDecoration(label: label('Property', 'property')),
            items: [for (final p in repo.properties) DropdownMenuItem(value: p, child: Text(p))],
            onChanged: (v) => setState(() => _property = v!),
          ),
          const SizedBox(height: Space.md),
        ],
        TextField(controller: _guest, textCapitalization: TextCapitalization.words, decoration: InputDecoration(label: label('Guest name', 'guest_name'))),
        const SizedBox(height: Space.md),
        InkWell(
          borderRadius: BorderRadius.circular(Radii.field),
          onTap: _pickDates,
          child: InputDecorator(
            decoration: InputDecoration(label: label('Dates', 'check_in'), prefixIcon: const Icon(LucideIcons300.calendar, size: 18)),
            child: Text('${fmtDate(_in)}  →  ${fmtDate(_out)}   ·   ${plural(nights, 'night')}', style: AppText.num(context, size: 15).copyWith(color: c.ink)),
          ),
        ),
        const SizedBox(height: Space.md),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _guests,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(label: label('Guests', 'guests_count')),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(flex: 2, child: TextField(controller: _ref, decoration: InputDecoration(label: label('Booking ID', 'platform_booking_id')))),
        ]),
        const SizedBox(height: Space.xl),
        Text('Money', style: AppText.label(context)),
        const SizedBox(height: Space.sm),
        AmountField(controller: _paid, label: _edited('guest_total_paid') ? 'Guest paid (edited)' : 'Guest paid (whole stay)', onChanged: (_) => setState(() {})),
        const SizedBox(height: Space.md),
        Row(children: [
          Expanded(child: AmountField(controller: _inHand, label: 'In hand', onChanged: (_) => setState(() {}))),
          const SizedBox(width: Space.md),
          Expanded(child: AmountField(controller: _costs, label: 'Costs', onChanged: (_) => setState(() {}))),
        ]),
        const SizedBox(height: Space.md),
        _Preview(f),
        if (e != null) ...[
          const SizedBox(height: Space.xl),
          Text('Status', style: AppText.label(context)),
          const SizedBox(height: Space.sm),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'confirmed', label: Text('Confirmed')),
              ButtonSegment(value: 'completed', label: Text('Completed')),
              ButtonSegment(value: 'cancelled', label: Text('Cancelled')),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
        ],
        const SizedBox(height: Space.md),
        TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: Space.md), child: Text(_error!, style: AppText.label(context).copyWith(color: c.danger))),
        const SizedBox(height: Space.xl),
        FilledButton(onPressed: _save, child: Text(e == null ? 'Add booking' : 'Save changes')),
        const SizedBox(height: Space.sm),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ]),
    );
  }
}

class _Preview extends StatelessWidget {
  final Financials f;
  const _Preview(this.f);
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget cell(String l, String v, {Color? color}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l, style: AppText.label(context).copyWith(fontSize: 11.5)),
            const SizedBox(height: 2),
            Text(v, style: AppText.money(context, size: 14.5).copyWith(color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        );
    return AnimatedOpacity(
      opacity: f.pending ? 0.55 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(color: c.surfaceAlt.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(Radii.field)),
        child: Row(children: [
          cell('Per night', inr(f.perNight)),
          cell('Platform cut', f.cut == null ? '—' : '${inr(f.cut)} · ${pct(f.cutPct)}'),
          cell('Profit', inr(f.profit), color: f.profit == null ? null : c.positive),
        ]),
      ),
    );
  }
}
