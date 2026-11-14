import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../data/import_file.dart';
import '../data/repository.dart';
import 'app_scope.dart';
import 'widgets/common.dart';

/// Pick a Booking Manager import file (.json), show what it holds, then add it.
Future<void> importFromFile(BuildContext context) async {
  final repo = context.repoRead;
  final ImportFile data;
  try {
    final file = await FilePicker.pickFile(dialogTitle: 'Choose the import file', type: FileType.any);
    if (file == null) return;
    data = ImportFile.parse(await file.xFile.readAsString());
  } on FormatException catch (e) {
    if (context.mounted) showError(context, e.message);
    return;
  } catch (e) {
    if (context.mounted) showError(context, 'Could not read that file.');
    return;
  }
  if (!context.mounted) return;

  final inHand = data.bookings.fold<double>(0, (s, b) => s + (b.inHandAmount ?? 0));
  final first = data.bookings.isEmpty ? null : data.bookings.map((b) => b.checkIn).reduce((a, b) => a.isBefore(b) ? a : b);
  final last = data.bookings.isEmpty ? null : data.bookings.map((b) => b.checkOut).reduce((a, b) => a.isAfter(b) ? a : b);
  final demo = repo.mode == Mode.demo;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Import this history?'),
      content: Text([
        '${plural(data.bookings.length, 'stay')}${data.blocks.isEmpty ? '' : ' and ${plural(data.blocks.length, 'blocked period')}'}',
        if (first != null && last != null) fmtRange(first, last),
        'In hand: ${inr(inHand)}',
        '',
        if (demo) 'The demo data will be deleted first. Your history is saved on this device only.'
        else 'Stays already imported from this file are updated, not added twice.',
      ].join('\n')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
      ],
    ),
  );
  if (ok != true) return;
  if (demo) await repo.startLocal();
  await repo.importFile(data);
  if (context.mounted) savedFeedback(context, 'Imported ${plural(data.bookings.length, 'stay')}');
}
