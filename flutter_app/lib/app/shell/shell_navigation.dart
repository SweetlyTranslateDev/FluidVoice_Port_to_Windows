import 'package:flutter/widgets.dart';

enum ShellPage {
  home,
  models,
  history,
  settings,
}

/// Lets nested pages switch the sidebar selection without stack pushes.
class ShellNavigation extends InheritedWidget {
  const ShellNavigation({
    super.key,
    required this.current,
    required this.goTo,
    required super.child,
  });

  final ShellPage current;
  final ValueChanged<ShellPage> goTo;

  static ShellNavigation? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellNavigation>();
  }

  static ShellNavigation of(BuildContext context) {
    final nav = maybeOf(context);
    assert(nav != null, 'ShellNavigation not found in context');
    return nav!;
  }

  @override
  bool updateShouldNotify(ShellNavigation oldWidget) {
    return current != oldWidget.current;
  }
}
