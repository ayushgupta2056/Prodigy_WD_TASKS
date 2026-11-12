import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'data/repository.dart';
import 'services/notifications.dart';
import 'theme/app_theme.dart';
import 'ui/app_scope.dart';
import 'ui/auto_sync.dart';
import 'ui/shell.dart';
import 'ui/screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The font ships with the app (assets/google_fonts), so it works offline.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Plus Jakarta Sans'], await rootBundle.loadString('assets/google_fonts/OFL.txt'));
  });
  await initializeDateFormatting('en_IN');
  final box = await _openStorage();
  final repo = Repository(box);
  await repo.load();
  // The web build is a preview only: open straight into demo data.
  if (repo.mode == Mode.unconfigured && kIsWeb) {
    await repo.startDemo();
  }
  // Notifications must never stop the app from starting.
  InHandReminders.instance.init().then((_) => InHandReminders.instance.schedule(repo.view.bookings)).catchError((_) {});
  repo.addListener(() => InHandReminders.instance.schedule(repo.view.bookings).catchError((_) {}));
  runApp(BookingApp(repo: repo));
}

/// On-device cache. If storage is unavailable (e.g. a locked-down browser),
/// fall back to memory so the app still opens.
Future<Box> _openStorage() async {
  try {
    await Hive.initFlutter('booking_manager');
    return await Hive.openBox('app');
  } catch (_) {
    return Hive.openBox('app-memory', bytes: Uint8List(0));
  }
}

class BookingApp extends StatelessWidget {
  final Repository repo;
  const BookingApp({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repo: repo,
      child: AutoSync(
        repo: repo,
        child: ListenableBuilder(
          listenable: repo,
          builder: (context, _) => MaterialApp(
            title: 'Booking Manager',
            debugShowCheckedModeBanner: false,
            scrollBehavior: const _AppScrollBehavior(),
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: switch (repo.themeMode) {
              'light' => ThemeMode.light,
              'dark' => ThemeMode.dark,
              _ => ThemeMode.system,
            },
            home: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              child: repo.mode == Mode.unconfigured ? const WelcomeScreen(key: ValueKey('welcome')) : const Shell(key: ValueKey('shell')),
            ),
          ),
        ),
      ),
    );
  }
}

/// In the browser preview, skip Android's stretch overscroll effect: it needs a
/// shader file that the preview host can't serve. Installed apps keep it.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) =>
      kIsWeb ? child : super.buildOverscrollIndicator(context, child, details);
}
