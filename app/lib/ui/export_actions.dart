import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import '../theme/icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/excel_export.dart';
import '../core/insights.dart';
import '../core/models.dart';
import '../services/file_saver.dart';
import '../theme/app_theme.dart';
import 'app_scope.dart';
import 'widgets/common.dart';

/// Ask "current view or everything?", build the .xlsx and save/share it.
Future<void> exportToExcel(BuildContext context, {Period? period, List<Booking>? filtered, String? property, String scopeLabel = 'Current view'}) async {
  final repo = context.repoRead;
  final choice = await showAdaptiveSheet<String>(context, builder: (ctx) {
    Widget option(String value, IconData icon, String title, String sub) => Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: AppCard(
            onTap: () => Navigator.pop(ctx, value),
            padding: const EdgeInsets.all(Space.lg),
            child: Row(children: [
              Icon(icon, color: ctx.colors.accent),
              const SizedBox(width: Space.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppText.title(ctx)), Text(sub, style: AppText.label(ctx))])),
              Icon(LucideIcons300.chevronRight, size: 16, color: ctx.colors.muted),
            ]),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Export to Excel', style: AppText.h2(ctx)),
      const SizedBox(height: 4),
      Text('A formatted workbook: Summary, Bookings, Monthly, Weekly, By Platform and Blocks.', style: AppText.label(ctx)),
      const SizedBox(height: Space.xl),
      option('current', LucideIcons300.funnel, scopeLabel, period?.label ?? 'With your current filters'),
      option('all', LucideIcons300.layers, 'Everything', 'All bookings and blocks'),
      if (repo.view.sheetXlsxUrl.isNotEmpty) option('sheet', LucideIcons300.hardDriveDownload, 'Download from Google Sheet', 'Opens your Sheet’s .xlsx download in the browser'),
    ]);
  });
  if (choice == null || !context.mounted) return;
  if (choice == 'sheet') {
    await launchUrl(Uri.parse(repo.view.sheetXlsxUrl), mode: LaunchMode.externalApplication);
    return;
  }
  final all = choice == 'all';
  final data = repo.insights(property: all ? null : property);
  final bytes = buildExport(data: data, period: all ? null : period, bookings: all ? null : filtered);
  final name = 'Bookings_${all ? 'all' : (period?.label ?? 'filtered').replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
  try {
    final where = await saveSpreadsheet(context, bytes, name);
    if (where != null && context.mounted) savedFeedback(context, where);
  } catch (e) {
    if (context.mounted) showError(context, 'Could not save the file: $e');
  }
}
