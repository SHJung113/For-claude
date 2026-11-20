import 'package:flutter/material.dart';

import 'click_wheel.dart';

/// One screen in the device's display. Screens receive wheel input
/// and call [refresh] when their state changes.
abstract class AppScreen with WheelHandler {
  late Nav nav;
  String get title;
  Widget build(BuildContext context);
  void refresh() => nav.refresh();
  void dispose() {}
}

/// Stack navigation like a classic player: MENU goes back one level.
class Nav extends ChangeNotifier with WheelHandler {
  Nav(AppScreen root) {
    push(root);
  }

  final List<AppScreen> stack = [];
  bool lastWasPush = true;

  AppScreen get top => stack.last;

  void push(AppScreen s) {
    s.nav = this;
    stack.add(s);
    lastWasPush = true;
    notifyListeners();
  }

  void pop() {
    if (stack.length <= 1) return;
    stack.removeLast().dispose();
    lastWasPush = false;
    notifyListeners();
  }

  void refresh() => notifyListeners();

  @override
  void onRotate(int steps) => top.onRotate(steps);
  @override
  void onCenter() => top.onCenter();
  @override
  void onCenterLong() => top.onCenterLong();
  @override
  void onMenu() => pop();
  @override
  void onPrev() => top.onPrev();
  @override
  void onNext() => top.onNext();
  @override
  void onBottom() => top.onBottom();
  @override
  void onBottomLong() => top.onBottomLong();
}
