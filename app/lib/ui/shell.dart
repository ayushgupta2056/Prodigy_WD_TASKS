import 'package:material_ui/material_ui.dart';
import '../theme/icons.dart';

import '../theme/app_theme.dart';
import 'app_scope.dart';
import 'screens/bookings_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/pending_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/unparsed_screen.dart';

class _Dest {
  final String label;
  final IconData icon;
  final IconData selected;
  final Widget page;
  final bool phone;
  const _Dest(this.label, this.icon, this.selected, this.page, {this.phone = true});
}

/// Bottom navigation on phones; a slim side rail with wider layouts on Windows.
class Shell extends StatefulWidget {
  const Shell({super.key});
  static void goTo(BuildContext context, String label) => context.findAncestorStateOfType<_ShellState>()?.goTo(label);
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  static const _dests = [
    _Dest('Home', LucideIcons300.house, LucideIcons500.house, DashboardScreen()),
    _Dest('Calendar', LucideIcons300.calendar, LucideIcons500.calendar, CalendarScreen()),
    _Dest('Bookings', LucideIcons300.list, LucideIcons500.list, BookingsScreen()),
    _Dest('Insights', LucideIcons300.chartLine, LucideIcons500.chartLine, InsightsScreen()),
    _Dest('In hand', LucideIcons300.handCoins, LucideIcons500.handCoins, PendingScreen(), phone: false),
    _Dest('Unparsed', LucideIcons300.mail, LucideIcons500.mail, UnparsedScreen(), phone: false),
    _Dest('Settings', LucideIcons300.settings, LucideIcons500.settings, SettingsScreen()),
  ];

  void goTo(String label) {
    final wide = context.isWide;
    final list = wide ? _dests : _dests.where((d) => d.phone).toList();
    final i = list.indexWhere((d) => d.label == label);
    if (i >= 0) {
      setState(() => _index = i);
    } else {
      final d = _dests.firstWhere((d) => d.label == label);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => d.page));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.repo;
    final wide = context.isWide;
    final dests = wide ? _dests : _dests.where((d) => d.phone).toList();
    if (_index >= dests.length) _index = 0;
    int badge(String label) => switch (label) {
          'In hand' => repo.pendingInHand.length,
          'Unparsed' => repo.view.unparsed.length,
          'Home' when !wide => repo.pendingInHand.length + repo.view.unparsed.length,
          _ => 0,
        };
    Widget icon(_Dest d, bool sel) {
      final n = badge(d.label);
      final i = Icon(sel ? d.selected : d.icon);
      return n == 0 ? i : Badge(label: Text('$n'), backgroundColor: context.colors.negative, child: i);
    }

    final body = IndexedStack(index: _index, children: [for (final d in dests) d.page]);
    if (!wide) {
      return Scaffold(
        body: body,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: context.colors.hairline))),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [for (final d in dests) NavigationDestination(icon: icon(d, false), selectedIcon: icon(d, true), label: d.label)],
          ),
        ),
      );
    }
    return Scaffold(
      body: Row(children: [
        DecoratedBox(
          decoration: BoxDecoration(border: Border(right: BorderSide(color: context.colors.hairline))),
          child: NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            minWidth: 84,
            groupAlignment: -0.85,
            leading: Padding(
              padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xl),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: context.colors.accent, borderRadius: BorderRadius.circular(12)),
                child: Icon(LucideIcons500.house, color: context.colors.onAccent, size: 22),
              ),
            ),
            destinations: [
              for (final d in dests)
                NavigationRailDestination(icon: icon(d, false), selectedIcon: icon(d, true), label: Text(d.label), padding: const EdgeInsets.symmetric(vertical: 4)),
            ],
          ),
        ),
        Expanded(child: body),
      ]),
    );
  }
}
