import 'package:flutter/material.dart';

import '../nav.dart';
import '../theme.dart';

class MenuItem {
  const MenuItem(this.label, {this.detail, this.open, this.enabled = true});
  final String label;
  final String? detail;
  final AppScreen Function()? open;
  final bool enabled;
}

/// Scrollable list menu with a single highlighted row.
class MenuScreen extends AppScreen {
  MenuScreen(this.title, this.items, {this.selected = 0});

  @override
  final String title;
  final List<MenuItem> items;
  int selected;

  static const rowHeight = 36.0;
  final _scroll = ScrollController();

  @override
  void onRotate(int steps) {
    selected = (selected + steps).clamp(0, items.length - 1);
    _ensureVisible();
    refresh();
  }

  void _ensureVisible() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final top = selected * rowHeight;
    if (top < pos.pixels) {
      _scroll.jumpTo(top);
    } else if (top + rowHeight > pos.pixels + pos.viewportDimension) {
      _scroll.jumpTo(top + rowHeight - pos.viewportDimension);
    }
  }

  @override
  void onCenter() {
    final item = items[selected];
    if (item.enabled && item.open != null) nav.push(item.open!());
  }

  @override
  void onNext() => onCenter();

  @override
  void dispose() => _scroll.dispose();

  @override
  Widget build(BuildContext context) {
    final pal = Palette.of(context);
    return ListView.builder(
      controller: _scroll,
      itemExtent: rowHeight,
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final sel = i == selected;
        final color = sel ? Colors.white : (item.enabled ? pal.text : pal.subtext);
        return GestureDetector(
          onTap: () {
            selected = i;
            onCenter();
            refresh();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: sel
                ? const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Palette.accentTop, Palette.accentBottom],
                    ),
                  )
                : null,
            child: Row(
              children: [
                Expanded(
                  child: Text(item.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                if (item.detail != null)
                  Text(item.detail!,
                      style: TextStyle(color: sel ? Colors.white70 : pal.subtext, fontSize: 13)),
                if (item.open != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(Icons.chevron_right_rounded, color: color, size: 20),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Placeholder for screens planned in later milestones.
class InfoScreen extends AppScreen {
  InfoScreen(this.title, this.message);
  @override
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final pal = Palette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(message,
            textAlign: TextAlign.center, style: TextStyle(color: pal.subtext, fontSize: 15)),
      ),
    );
  }
}
