import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import '../../theme/icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../app_scope.dart';
import '../widgets/common.dart';
import 'booking_form.dart';

/// Booking emails that were recognised but could not be read completely.
class UnparsedScreen extends StatelessWidget {
  const UnparsedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.repo;
    final c = context.colors;
    final list = repo.view.unparsed;
    return Scaffold(
      appBar: AppBar(title: const Text('Unparsed emails'), automaticallyImplyLeading: Navigator.of(context).canPop()),
      body: list.isEmpty
          ? const EmptyState(icon: LucideIcons300.mailOpen, title: 'No emails to review', message: 'Booking emails the app can’t read fully will show up here.')
          : PageBody(maxWidth: 760, onRefresh: () => repo.sync(checkEmails: true), children: [
              Text('These look like booking emails, but some details couldn’t be read. Create the booking yourself, or dismiss the email.', style: AppText.label(context)),
              const SizedBox(height: Space.lg),
              for (var i = 0; i < list.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: EaseIn(
                    index: i,
                    child: AppCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          PlatformDot(list[i].platform, size: 9),
                          const SizedBox(width: 8),
                          Text(list[i].platform, style: AppText.label(context).copyWith(color: c.inkSoft, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (list[i].receivedAt != null) Text(DateFormat('dd MMM yyyy, h:mm a').format(list[i].receivedAt!), style: AppText.label(context)),
                        ]),
                        const SizedBox(height: Space.sm),
                        Text(list[i].subject.isEmpty ? '(no subject)' : list[i].subject, style: AppText.title(context)),
                        if (list[i].error.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(list[i].error, style: AppText.label(context).copyWith(fontSize: 12)),
                        ],
                        const SizedBox(height: Space.lg),
                        Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
                          FilledButton.icon(
                            onPressed: () => showBookingForm(context, fromEmail: list[i]),
                            icon: const Icon(LucideIcons300.plus, size: 18),
                            label: const Text('Create booking'),
                          ),
                          OutlinedButton.icon(
                            onPressed: list[i].gmailUrl.isEmpty ? null : () => launchUrl(Uri.parse(list[i].gmailUrl), mode: LaunchMode.externalApplication),
                            icon: const Icon(LucideIcons300.externalLink, size: 18),
                            label: const Text('Open in Gmail'),
                          ),
                          TextButton(onPressed: () => repo.dismissUnparsed(list[i].emailMessageId), child: const Text('Dismiss')),
                        ]),
                      ]),
                    ),
                  ),
                ),
            ]),
    );
  }
}
