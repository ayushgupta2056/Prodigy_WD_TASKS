import 'package:material_ui/material_ui.dart';
import '../../theme/icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repository.dart';
import '../../theme/app_theme.dart';
import '../app_scope.dart';
import '../export_actions.dart';
import '../import_actions.dart';
import '../widgets/booking_widgets.dart';
import '../widgets/common.dart';
import 'pending_screen.dart';
import 'unparsed_screen.dart';
import 'welcome_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.repo;
    final c = context.colors;

    Widget tile(IconData icon, String title, {String? subtitle, VoidCallback? onTap, Widget? trailing, Color? color}) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 2),
          leading: Icon(icon, color: color ?? c.inkSoft, size: 21),
          title: Text(title, style: AppText.title(context).copyWith(color: color, fontWeight: FontWeight.w500)),
          subtitle: subtitle == null ? null : Text(subtitle, style: AppText.label(context), maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: trailing ?? (onTap == null ? null : Icon(LucideIcons300.chevronRight, size: 16, color: c.muted)),
          onTap: onTap,
        );
    Widget group(List<Widget> children) => AppCard(padding: const EdgeInsets.symmetric(vertical: Space.xs), child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(indent: 56), children[i]],
        ]));

    return Scaffold(
      body: SafeArea(
        child: PageBody(maxWidth: 720, children: [
          const SizedBox(height: Space.lg),
          Text('Settings', style: AppText.h1(context)),
          const SizedBox(height: Space.md),
          const SyncStatus(),
          const SectionHeader('Connection'),
          group([
            tile(
              switch (repo.mode) { Mode.demo => LucideIcons300.sparkles, Mode.local => LucideIcons300.hardDrive, _ => LucideIcons300.plug },
              switch (repo.mode) { Mode.demo => 'Demo data', Mode.local => 'Saved on this device only', _ => 'Google Sheet backend' },
              subtitle: switch (repo.mode) {
                Mode.demo => 'Nothing is saved to Google. Connect your Sheet to start.',
                Mode.local => 'No email reading or syncing. Tap to connect your Google Sheet; your entries will be uploaded to it.',
                _ => _mask(repo.url),
              },
              onTap: () => showAdaptiveSheet<void>(context, builder: (ctx) => SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('Connect your Google Sheet', style: AppText.h2(ctx)),
                      const SizedBox(height: 4),
                      Text('In the Sheet: Booking App → Show Web App URL and API key.', style: AppText.label(ctx)),
                      const SizedBox(height: Space.xl),
                      ConnectForm(onConnected: () {
                        Navigator.pop(ctx);
                        savedFeedback(context, 'Connected');
                      }),
                    ]),
                  )),
            ),
            if (repo.mode != Mode.local)
              tile(LucideIcons300.refreshCw, 'Sync now', subtitle: 'Send changes, check Gmail for new bookings', onTap: repo.syncing ? null : () => repo.sync(checkEmails: true)),
            if (repo.mode == Mode.demo)
              tile(LucideIcons300.eraser, 'Delete demo data and start empty', subtitle: 'Your own entries will be saved on this device only', onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Start empty?'),
                    content: const Text('All demo bookings are removed. What you add from now on is saved on this device only.'),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start empty'))],
                  ),
                );
                if (ok == true) {
                  await repo.startLocal();
                  if (context.mounted) savedFeedback(context, 'Demo data deleted');
                }
              }),
          ]),
          const SectionHeader('Properties'),
          const _PropertiesEditor(),
          const SectionHeader('Review'),
          group([
            tile(LucideIcons300.handCoins, 'Pending in-hand amounts',
                trailing: _count(context, repo.pendingInHand.length), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingScreen()))),
            tile(LucideIcons300.mail, 'Unparsed emails',
                trailing: _count(context, repo.view.unparsed.length), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UnparsedScreen()))),
          ]),
          const SectionHeader('Data'),
          group([
            tile(LucideIcons300.fileUp, 'Import bookings from file', subtitle: 'Add past stays from a Booking Manager import file (.json)', onTap: () => importFromFile(context)),
            tile(LucideIcons300.fileSpreadsheet, 'Export everything to Excel', onTap: () => exportToExcel(context)),
            if (repo.view.sheetXlsxUrl.isNotEmpty)
              tile(LucideIcons300.hardDriveDownload, 'Download from Google Sheet', subtitle: 'The raw Sheet as .xlsx',
                  onTap: () => launchUrl(Uri.parse(repo.view.sheetXlsxUrl), mode: LaunchMode.externalApplication)),
          ]),
          const SectionHeader('Appearance'),
          AppCard(
            padding: const EdgeInsets.all(Space.lg),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'system', label: Text('Auto'), icon: Icon(LucideIcons300.sunMoon, size: 16)),
                ButtonSegment(value: 'light', label: Text('Light'), icon: Icon(LucideIcons300.sun, size: 16)),
                ButtonSegment(value: 'dark', label: Text('Dark'), icon: Icon(LucideIcons300.moon, size: 16)),
              ],
              selected: {repo.themeMode},
              onSelectionChanged: (s) => repo.setThemeMode(s.first),
            ),
          ),
          const SizedBox(height: Space.xxl),
          group([
            tile(LucideIcons300.logOut, switch (repo.mode) { Mode.demo => 'Leave demo', Mode.local => 'Delete all data on this device', _ => 'Disconnect this device' }, color: c.negative, onTap: () async {
              final local = repo.mode == Mode.local;
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(local ? 'Delete everything?' : 'Disconnect?'),
                  content: Text(local
                      ? 'Your bookings are saved only on this device, so this deletes them for good. Export to Excel first if you want a copy.'
                      : 'Clears the data saved on this device. Your Google Sheet is not touched.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(local ? 'Delete' : 'Disconnect'))],
                ),
              );
              if (ok == true) await repo.signOut();
            }),
          ]),
          const SizedBox(height: Space.lg),
          Center(child: Text('Booking Manager · v1.0.0', style: AppText.label(context))),
        ]),
      ),
    );
  }

  static String _mask(String url) {
    final m = RegExp(r'/s/([^/]+)/').firstMatch(url);
    if (m == null) return url;
    final id = m[1]!;
    return 'script.google.com/…/${id.substring(0, 6)}…${id.substring(id.length - 4)}/exec';
  }

  static Widget _count(BuildContext context, int n) => n == 0
      ? Icon(LucideIcons300.chevronRight, size: 16, color: context.colors.muted)
      : Pill('$n', color: context.colors.warning, background: context.colors.warning.withValues(alpha: 0.12));
}

class _PropertiesEditor extends StatefulWidget {
  const _PropertiesEditor();
  @override
  State<_PropertiesEditor> createState() => _PropertiesEditorState();
}

class _PropertiesEditorState extends State<_PropertiesEditor> {
  final _add = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final repo = context.repo;
    final props = repo.properties;
    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in props)
            InputChip(
              label: Text(p),
              onDeleted: props.length <= 1 ? null : () => repo.setProperties(props.where((x) => x != p).toList()),
            ),
        ]),
        const SizedBox(height: Space.md),
        Row(children: [
          Expanded(child: TextField(controller: _add, decoration: const InputDecoration(hintText: 'Add a property'), onSubmitted: (_) => _submit(props))),
          const SizedBox(width: Space.sm),
          IconButton.filledTonal(onPressed: () => _submit(props), icon: const Icon(LucideIcons300.plus)),
        ]),
      ]),
    );
  }

  void _submit(List<String> props) {
    final v = _add.text.trim();
    if (v.isEmpty || props.contains(v)) return;
    context.repoRead.setProperties([...props, v]);
    _add.clear();
  }
}
