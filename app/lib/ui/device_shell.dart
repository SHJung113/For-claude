import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'click_wheel.dart';
import 'nav.dart';
import 'theme.dart';

/// The "device": a display panel plus the click wheel.
/// Portrait (phone): display on top, wheel below.
/// Landscape (desktop): display left, wheel right.
class DeviceShell extends StatelessWidget {
  const DeviceShell({super.key, required this.nav});
  final Nav nav;

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      nav.onRotate(1);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      nav.onRotate(-1);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      nav.onNext();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      nav.onPrev();
    } else if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.enter) {
      nav.onCenter();
    } else if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.backspace) {
      nav.onMenu();
    } else if (k == LogicalKeyboardKey.keyR) {
      nav.onBottom();
    } else if (k == LogicalKeyboardKey.keyT) {
      nav.onBottomLong();
    } else if (k == LogicalKeyboardKey.keyS) {
      nav.onCenterLong();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final pal = Palette.of(context);
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [pal.bodyTop, pal.bodyBottom],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > c.maxHeight * 1.15 && c.maxWidth > 640;
            if (wide) {
              final wheel = (c.maxHeight * 0.62).clamp(220.0, 340.0);
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 560),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Row(children: [
                      Expanded(child: _Display(nav: nav)),
                      const SizedBox(width: 40),
                      ClickWheel(handler: nav, size: wheel),
                    ]),
                  ),
                ),
              );
            }
            final wheel = (c.maxWidth * 0.72).clamp(200.0, 300.0);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(children: [
                    Expanded(child: _Display(nav: nav)),
                    const SizedBox(height: 28),
                    ClickWheel(handler: nav, size: wheel),
                  ]),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _Display extends StatelessWidget {
  const _Display({required this.nav});
  final Nav nav;

  @override
  Widget build(BuildContext context) {
    final pal = Palette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: pal.screen,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pal.screenBorder, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ListenableBuilder(
        listenable: nav,
        builder: (context, _) {
          final top = nav.top;
          return Column(children: [
            _TitleBar(title: top.title, depth: nav.stack.length),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) {
                  final incoming = child.key == ValueKey(nav.stack.length);
                  final dir = nav.lastWasPush == incoming ? 1.0 : -1.0;
                  return SlideTransition(
                    position: Tween(begin: Offset(dir, 0), end: Offset.zero).animate(anim),
                    child: child,
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(nav.stack.length),
                  child: top.build(context),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.title, required this.depth});
  final String title;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final pal = Palette.of(context);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [pal.screen, pal.screenBorder.withValues(alpha: 0.35)],
        ),
        border: Border(bottom: BorderSide(color: pal.screenBorder)),
      ),
      child: Row(children: [
        SizedBox(
          width: 40,
          child: depth > 1 ? Icon(Icons.chevron_left_rounded, size: 18, color: pal.subtext) : null,
        ),
        Expanded(
          child: Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(color: pal.text, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        SizedBox(
          width: 40,
          child: Align(
            alignment: Alignment.centerRight,
            child: Icon(Icons.headphones_rounded, size: 16, color: pal.subtext),
          ),
        ),
      ]),
    );
  }
}
