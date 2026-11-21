import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../data/content.dart';
import '../data/levels.dart';
import '../player/tts_player.dart';
import '../player/youtube_sentence_player.dart';
import '../youtube/pack.dart';
import 'app_theme.dart';
import 'player_page.dart';
import 'youtube_add_page.dart';

/// Placement test arrives with M2; until then everyone starts at L1.
const currentLevel = 1;

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.catalog});
  final List<Content> catalog;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _TodayTab(catalog: widget.catalog),
      _LevelsTab(catalog: widget.catalog),
      const _YouTubeTab(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: '오늘'),
          NavigationDestination(
              icon: Icon(Icons.stairs_outlined), selectedIcon: Icon(Icons.stairs), label: '레벨'),
          NavigationDestination(
              icon: Icon(Icons.smart_display_outlined),
              selectedIcon: Icon(Icons.smart_display),
              label: 'YouTube'),
        ],
      ),
    );
  }
}

void openContent(BuildContext context, Content c) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PlayerPage(
      title: c.title,
      subtitle: 'L${c.level} · ${c.track == 'news' ? 'News' : 'Daily'} · ${fmtDuration(c.duration)}',
      createPlayer: () => TtsPlayer(c),
    ),
  ));
}

void openPack(BuildContext context, YouTubePack pk) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PlayerPage(
      title: pk.title,
      subtitle: '${pk.channel} · ≈L${pk.estimatedLevel} · ${pk.wpm} wpm',
      createPlayer: () => YouTubeSentencePlayer(pk),
      header: (p) => YoutubePlayer(controller: (p as YouTubeSentencePlayer).controller),
      expressions: pk.expressions,
      initialMode: TextMode.sentence,
      modes: [
        TextMode.blind,
        TextMode.sentence,
        pk.hasTranslation ? TextMode.translation : TextMode.script,
        if (pk.expressions.isNotEmpty) TextMode.expressions,
      ],
    ),
  ));
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

class ContentTile extends StatelessWidget {
  const ContentTile(this.c, {super.key});
  final Content c;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final news = c.track == 'news';
    return Card(
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: CircleAvatar(
          backgroundColor: news ? cs.tertiaryContainer : cs.secondaryContainer,
          child: Icon(news ? Icons.newspaper_rounded : Icons.forum_rounded,
              color: news ? cs.onTertiaryContainer : cs.onSecondaryContainer, size: 20),
        ),
        title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${news ? 'News' : 'Daily'} · ${c.sentences.length}문장 · ${fmtDuration(c.duration)}'),
        trailing: const Icon(Icons.play_circle_fill_rounded, size: 32),
        onTap: () => openContent(context, c),
      ),
    );
  }
}

class _TodayTab extends StatelessWidget {
  const _TodayTab({required this.catalog});
  final List<Content> catalog;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lv = levels[currentLevel - 1];
    final items = catalog.where((c) => c.level == currentLevel).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const _Header('오늘의 학습', '대본 없이 먼저 듣고, 안 들린 문장만 반복하세요'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            color: cs.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('현재 레벨', style: TextStyle(color: cs.onPrimaryContainer)),
                  Text('L${lv.no}',
                      style: TextStyle(
                          fontSize: 40, fontWeight: FontWeight.w800, color: cs.onPrimaryContainer)),
                ]),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${lv.stage} · ${lv.grade}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: cs.onPrimaryContainer)),
                    Text('${lv.wpm} wpm · 콘텐츠 ${items.length}개',
                        style: TextStyle(color: cs.onPrimaryContainer)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final c in items)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: ContentTile(c)),
      ],
    );
  }
}

class _LevelsTab extends StatelessWidget {
  const _LevelsTab({required this.catalog});
  final List<Content> catalog;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = <Widget>[const _Header('레벨', '미국 유치원에서 대학까지, 20단계')];
    String? stage;
    for (final l in levels) {
      if (l.stage != stage) {
        stage = l.stage;
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: Text(l.stage,
              style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary, letterSpacing: 0.3)),
        ));
      }
      final n = catalog.where((c) => c.level == l.no).length;
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Card(
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            leading: CircleAvatar(
              backgroundColor: n > 0 ? cs.primary : cs.surfaceContainerHighest,
              foregroundColor: n > 0 ? cs.onPrimary : cs.onSurfaceVariant,
              child: Text('${l.no}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            title: Text(l.grade, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${l.wpm} wpm'),
            trailing: n > 0 ? Tag('$n개', strong: true) : const Tag('준비 중'),
            onTap: n == 0
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _LevelPage(level: l, items: catalog.where((c) => c.level == l.no).toList()),
                    )),
          ),
        ),
      ));
    }
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: rows);
  }
}

class _LevelPage extends StatelessWidget {
  const _LevelPage({required this.level, required this.items});
  final Level level;
  final List<Content> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('L${level.no} · ${level.grade}')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => ContentTile(items[i]),
      ),
    );
  }
}

class _YouTubeTab extends StatefulWidget {
  const _YouTubeTab();

  @override
  State<_YouTubeTab> createState() => _YouTubeTabState();
}

class _YouTubeTabState extends State<_YouTubeTab> {
  List<YouTubePack> packs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await PackStore.list();
    if (mounted) setState(() => packs = list);
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _importFile() async {
    try {
      final n = await PackStore.importFromPicker();
      if (n == 0) return;
      _snack('학습 팩 $n개를 가져왔습니다');
    } on FormatException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('가져오기 실패: $e');
    }
    await _load();
  }

  Future<void> _add() async {
    final n = await Navigator.of(context)
        .push<int>(MaterialPageRoute(builder: (_) => const YouTubeAddPage()));
    if (n != null && n > 0) {
      _snack('학습 팩 $n개를 만들었습니다');
      await _load();
    }
  }

  Future<void> _delete(YouTubePack pk) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('삭제할까요?'),
        content: Text(pk.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) {
      await PackStore.delete(pk);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const _Header('YouTube', '학습 팩으로 실제 영상을 문장 단위로 공부해요'),
        if (!youtubeSupported)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('YouTube 학습은 Android 폰에서 사용할 수 있습니다.',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _add,
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('링크와 자막으로 추가'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              onPressed: _importFile,
              icon: const Icon(Icons.file_open_rounded),
              label: const Text('학습 팩 파일 가져오기 (해석 포함)'),
            ),
          ),
          const SizedBox(height: 12),
          if (packs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('아직 가져온 학습 팩이 없습니다.',
                  textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          for (final pk in packs)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Card(
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  leading: CircleAvatar(
                    backgroundColor: cs.errorContainer,
                    child: Icon(Icons.smart_display_rounded, color: cs.onErrorContainer, size: 20),
                  ),
                  title: Text(pk.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${pk.sentences.length}문장${pk.hasTranslation ? ' · 해석 있음' : ''}'),
                  trailing: Tag('≈L${pk.estimatedLevel}', strong: true),
                  onTap: () => openPack(context, pk),
                  onLongPress: () => _delete(pk),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
