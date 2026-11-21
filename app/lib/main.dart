import 'package:flutter/material.dart';

import 'data/content.dart';
import 'data/levels.dart';
import 'ui/device_shell.dart';
import 'ui/nav.dart';
import 'ui/screens/listening_screen.dart';
import 'ui/screens/menu_screen.dart';
import 'ui/screens/youtube_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ListenUpApp());
}

class ListenUpApp extends StatefulWidget {
  const ListenUpApp({super.key});

  @override
  State<ListenUpApp> createState() => _ListenUpAppState();
}

class _ListenUpAppState extends State<ListenUpApp> {
  Nav? _nav;

  @override
  void initState() {
    super.initState();
    loadCatalog().then((c) => setState(() => _nav = Nav(buildRootMenu(c))));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ListenUp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF2F6FCB)),
      home: Scaffold(
        body: _nav == null
            ? const Center(child: CircularProgressIndicator())
            : DeviceShell(nav: _nav!),
      ),
    );
  }
}

const _later = '이 화면은 M2 단계에서 추가됩니다.';

MenuScreen buildRootMenu(List<Content> catalog) {
  const currentLevel = 1; // placement test arrives in M2
  final today = catalog.where((c) => c.level == currentLevel).toList();

  AppScreen levelScreen(Level l) {
    final items = catalog.where((c) => c.level == l.no).toList();
    if (items.isEmpty) {
      return InfoScreen('Level ${l.no}', '${l.grade} · ${l.wpm} wpm\n\n콘텐츠 준비 중입니다.');
    }
    return MenuScreen('Level ${l.no}', [
      for (final c in items)
        MenuItem(c.title,
            detail: c.track == 'news' ? 'News' : 'Daily', open: () => ListeningScreen(c)),
    ]);
  }

  return MenuScreen('ListenUp', [
    MenuItem("Today's Lesson",
        detail: 'L$currentLevel',
        open: () => today.isEmpty
            ? InfoScreen("Today's Lesson", '콘텐츠 준비 중입니다.')
            : levelScreen(levels[currentLevel - 1])),
    MenuItem('Levels',
        open: () => MenuScreen('Levels', [
              for (final l in levels)
                MenuItem('L${l.no}  ${l.grade}',
                    detail: '${catalog.where((c) => c.level == l.no).length}',
                    open: () => levelScreen(l)),
            ])),
    MenuItem('YouTube', open: () => YouTubeHome()),
    MenuItem('Review', open: () => InfoScreen('Review', _later)),
    MenuItem('Progress', open: () => InfoScreen('Progress', _later)),
    MenuItem('Settings', open: () => InfoScreen('Settings', _later)),
  ]);
}
