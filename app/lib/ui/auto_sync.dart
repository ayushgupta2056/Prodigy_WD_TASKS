import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../data/repository.dart';

/// Keeps every device up to date with the Google Sheet:
/// * every [interval] while the app is open and in front, and
/// * whenever you come back to the app (if the last sync is older than
///   [resumeAfter]).
/// Nothing runs while the app is in the background.
class AutoSync extends StatefulWidget {
  final Repository repo;
  final Widget child;
  final Duration interval;
  final Duration resumeAfter;
  const AutoSync({
    super.key,
    required this.repo,
    required this.child,
    this.interval = const Duration(minutes: 2),
    this.resumeAfter = const Duration(seconds: 30),
  });

  @override
  State<AutoSync> createState() => _AutoSyncState();
}

class _AutoSyncState extends State<AutoSync> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) => _syncIfLive());
  }

  void _syncIfLive({Duration? olderThan}) {
    final r = widget.repo;
    if (r.mode != Mode.live || r.syncing) return;
    if (olderThan != null && r.lastSyncAt != null && DateTime.now().difference(r.lastSyncAt!) < olderThan) return;
    r.sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncIfLive(olderThan: widget.resumeAfter);
      _start();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
