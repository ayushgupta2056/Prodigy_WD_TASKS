import 'package:material_ui/material_ui.dart';

import '../data/repository.dart';

class AppScope extends InheritedNotifier<Repository> {
  const AppScope({super.key, required Repository repo, required super.child}) : super(notifier: repo);

  static Repository of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static Repository read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

extension RepoX on BuildContext {
  /// Rebuilds when data changes.
  Repository get repo => AppScope.of(this);

  /// For callbacks: no rebuild dependency.
  Repository get repoRead => AppScope.read(this);
}
