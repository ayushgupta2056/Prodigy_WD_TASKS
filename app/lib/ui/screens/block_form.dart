import 'package:material_ui/material_ui.dart';
import '../../theme/icons.dart';

import '../../core/dates.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../theme/app_theme.dart';
import '../app_scope.dart';
import '../widgets/common.dart';

/// Block dates (no booking): personal use, maintenance, held, other.
Future<void> showBlockForm(BuildContext context, {Block? existing, DateTime? start, DateTime? end, String? property}) =>
    showAdaptiveSheet<void>(context, builder: (_) => _BlockForm(existing: existing, start: start, end: end, property: property));

class _BlockForm extends StatefulWidget {
  final Block? existing;
  final DateTime? start;
  final DateTime? end;
  final String? property;
  const _BlockForm({this.existing, this.start, this.end, this.property});
  @override
  State<_BlockForm> createState() => _BlockFormState();
}

class _BlockFormState extends State<_BlockForm> {
  late final repo = context.repoRead;
  late DateTime _start = widget.existing?.startDate ?? widget.start ?? today();
  late DateTime _end = widget.existing?.endDate ?? widget.end ?? _start;
  late String _reason = widget.existing?.reason ?? 'personal use';
  late String _property = widget.existing?.property.isNotEmpty == true ? widget.existing!.property : (widget.property ?? repo.defaultProperty);
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');

  Future<void> _pick() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2018),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: DateTime(_start.year, _start.month, _start.day), end: DateTime(_end.year, _end.month, _end.day)),
      helpText: 'First and last blocked night',
    );
    if (r != null) {
      setState(() {
        _start = DateTime.utc(r.start.year, r.start.month, r.start.day);
        _end = DateTime.utc(r.end.year, r.end.month, r.end.day);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nights = daysBetween(_start, _end) + 1;
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.existing == null ? 'Block dates' : 'Blocked dates', style: AppText.h2(context)),
        const SizedBox(height: 4),
        Text('Blocked nights are not available to sell and don’t count against occupancy.', style: AppText.label(context)),
        const SizedBox(height: Space.xl),
        InkWell(
          borderRadius: BorderRadius.circular(Radii.field),
          onTap: _pick,
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Nights', prefixIcon: Icon(LucideIcons300.calendarX, size: 18)),
            child: Text('${fmtDate(_start)} – ${fmtDate(_end)}   ·   ${plural(nights, 'night')}', style: AppText.num(context, size: 15).copyWith(color: context.colors.ink)),
          ),
        ),
        const SizedBox(height: Space.lg),
        Text('Reason', style: AppText.label(context)),
        const SizedBox(height: Space.sm),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in blockReasons) ChoiceChip(label: Text(r[0].toUpperCase() + r.substring(1)), selected: _reason == r, onSelected: (_) => setState(() => _reason = r)),
        ]),
        if (repo.properties.length > 1) ...[
          const SizedBox(height: Space.lg),
          DropdownButtonFormField<String>(
            initialValue: repo.properties.contains(_property) ? _property : repo.properties.first,
            decoration: const InputDecoration(labelText: 'Property'),
            items: [for (final p in repo.properties) DropdownMenuItem(value: p, child: Text(p))],
            onChanged: (v) => setState(() => _property = v!),
          ),
        ],
        const SizedBox(height: Space.lg),
        TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
        const SizedBox(height: Space.xl),
        FilledButton(
          onPressed: () async {
            await repo.saveBlock(Block(id: widget.existing?.id ?? repo.newId(), property: _property, startDate: _start, endDate: _end, reason: _reason, notes: _notes.text.trim()));
            if (!context.mounted) return;
            Navigator.pop(context);
            savedFeedback(context, 'Dates blocked');
          },
          child: Text(widget.existing == null ? 'Block ${plural(nights, 'night')}' : 'Save'),
        ),
        if (widget.existing != null) ...[
          const SizedBox(height: Space.sm),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: context.colors.danger),
            onPressed: () async {
              await repo.deleteBlock(widget.existing!.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              savedFeedback(context, 'Dates unblocked');
            },
            icon: const Icon(LucideIcons300.lockOpen, size: 18),
            label: const Text('Unblock'),
          ),
        ],
        const SizedBox(height: Space.sm),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ]),
    );
  }
}
