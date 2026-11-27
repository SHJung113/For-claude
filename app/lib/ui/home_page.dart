import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../data/content.dart';
import '../data/levels.dart';
import '../data/study_store.dart';
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
    // Built inside the builder: progress, streak and saved sentences live in
    // [study], and fresh widgets are needed for the tab to repaint on change.
    Widget page() => switch (tab) {
          0 => _TodayTab(catalog: widget.catalog),
          1 => _LevelsTab(catalog: widget.catalog),
          2 => const _YouTubeTab(),
          _ => _SavedTab(catalog: widget.catalog),
        };
    return Scaffold(
      body: SafeArea(child: ListenableBuilder(listenable: study, builder: (_, _) => page())),
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
          NavigationDestination(
              icon: Icon(Icons.star_outline_rounded), selectedIcon: Icon(Icons.star_rounded), label: '저장'),
        ],
      ),
    );
  }
}

String ttsKey(Content c) => 'tts:${c.id}';
String ytKey(YouTubePack pk) => 'yt:${pk.fileName}';

void openContent(BuildContext context, Content c, {int? at}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PlayerPage(
      contentKey: ttsKey(c),
      startIndex: at,
      title: c.title,
      subtitle: 'L${c.level} · ${c.track == 'news' ? 'News' : 'Daily'} · ${fmtDuration(c.duration)}',
      createPlayer: () => TtsPlayer(c),
      background: true,
    ),
  ));
}

void openPack(BuildContext context, YouTubePack pk, {int? at}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PlayerPage(
      contentKey: ytKey(pk),
      startIndex: at,
      title: pk.title,
      subtitle: '${pk.channel} · ≈L${pk.estimatedLevel} · ${pk.wpm} wpm',
      createPlayer: () => YouTubeSentencePlayer(pk),
      header: (p) => _VideoHeader(player: p as YouTubeSentencePlayer),
      expressions: pk.expressions,
      initialMode: TextMode.sentence,
    ),
  ));
}

/// Opens whatever a progress / saved-sentence key points to.
Future<void> openByKey(BuildContext context, List<Content> catalog, String key, {int? at}) async {
  if (key.startsWith('tts:')) {
    final c = catalog.where((c) => ttsKey(c) == key).firstOrNull;
    if (c != null) return openContent(context, c, at: at);
  } else if (key.startsWith('yt:')) {
    final pk = (await PackStore.list()).where((p) => ytKey(p) == key).firstOrNull;
    if (pk != null && context.mounted) {
      if (!youtubeSupported) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('YouTube 학습은 Android 폰에서 사용할 수 있습니다.')));
        return;
      }
      return openPack(context, pk, at: at);
    }
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('원래 콘텐츠를 찾을 수 없습니다.')));
  }
}

/// The embedded YouTube player, with a readable message if it can't play.
class _VideoHeader extends StatelessWidget {
  const _VideoHeader({required this.player});
  final YouTubeSentencePlayer player;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final err = player.errorMessage;
    return Stack(children: [
      YoutubePlayer(controller: player.controller),
      if (err != null)
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.75),
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline_rounded, color: cs.errorContainer, size: 32),
              const SizedBox(height: 8),
              Text(err, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15)),
            ]),
          ),
        ),
    ]);
  }
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
        trailing: _ProgressBadge(key_: ttsKey(c), total: c.sentences.length),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _Stat(icon: Icons.local_fire_department_rounded, value: '${study.streakDays}일', label: '연속 학습'),
            const SizedBox(width: 8),
            _Stat(icon: Icons.timer_outlined, value: '${study.todayMinutes}분', label: '오늘 들은 시간'),
            const SizedBox(width: 8),
            _Stat(
                icon: Icons.task_alt_rounded,
                value: '${items.where((c) => study.isDone(ttsKey(c))).length}/${items.length}',
                label: '이 단계 완료'),
          ]),
        ),
        if (study.last != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: cs.secondaryContainer,
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                leading: Icon(Icons.play_circle_rounded, size: 36, color: cs.onSecondaryContainer),
                title: const Text('이어서 하기', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${study.last!['title']} · 문장 ${study.lastIndex(study.last!['key'] as String) + 1}부터',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                onTap: () => openByKey(context, catalog, study.last!['key'] as String),
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text('L${lv.no} 콘텐츠', style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
        ),
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

  /// Packs grouped by video, keeping the stored order (video, then time).
  List<List<YouTubePack>> _byVideo() {
    final groups = <String, List<YouTubePack>>{};
    for (final pk in packs) {
      groups.putIfAbsent(pk.videoId, () => []).add(pk);
    }
    return groups.values.toList();
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

  Future<void> _options(YouTubePack pk) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text('해석 요청용으로 복사'),
            subtitle: const Text('이 영상의 모든 챕터 자막을 복사해 Claude 대화에 붙여넣기'),
            onTap: () => Navigator.pop(c, 'copy'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text('삭제'),
            onTap: () => Navigator.pop(c, 'delete'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (action == 'copy') {
      final same = packs.where((p) => p.videoId == pk.videoId).toList();
      await Clipboard.setData(ClipboardData(text: YouTubePack.requestText(same)));
      _snack('챕터 ${same.length}개 자막을 복사했습니다. Claude 대화에 붙여넣어 주세요.');
    } else if (action == 'delete') {
      await _delete(pk);
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
          for (final group in _byVideo())
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _VideoCard(
                packs: group,
                onOpen: (pk) => openPack(context, pk),
                onMore: _options,
              ),
            ),
        ],
      ],
    );
  }
}

/// One video: thumbnail header + its chapters.
class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.packs, required this.onOpen, required this.onMore});
  final List<YouTubePack> packs;
  final void Function(YouTubePack) onOpen;
  final void Function(YouTubePack) onMore;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final first = packs.first;
    final translated = packs.where((p) => p.hasTranslation).length;
    final sentences = packs.fold<int>(0, (a, p) => a + p.sentences.length);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 120,
                height: 68,
                // Official thumbnail image (no video data).
                child: Image.network(
                  'https://i.ytimg.com/vi/${first.videoId}/mqdefault.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: cs.surfaceContainerHighest,
                    child: Icon(Icons.smart_display_rounded, color: cs.onSurfaceVariant, size: 32),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(first.channel.isEmpty ? 'YouTube' : first.channel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('챕터 ${packs.length}개 · $sentences문장',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Tag(translated == packs.length ? '해석 있음' : '해석 $translated/${packs.length}',
                    strong: translated == packs.length),
              ]),
            ),
          ]),
        ),
        Divider(height: 1, color: cs.outlineVariant),
        for (final pk in packs)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 16, right: 4),
            leading: Icon(
                pk.hasTranslation ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: pk.hasTranslation ? cs.primary : cs.outline,
                size: 20),
            title: Text(pk.title,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle: Text('${pk.sentences.length}문장 · ≈L${pk.estimatedLevel}${pk.hasTranslation ? '' : ' · 해석 없음'}'),
            trailing: IconButton(
              tooltip: '더보기',
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () => onMore(pk),
            ),
            onTap: () => onOpen(pk),
            onLongPress: () => onMore(pk),
          ),
      ]),
    );
  }
}

/// Done check / "3/11" / play icon for a content row.
class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.key_, required this.total});
  final String key_;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (study.isDone(key_)) return Icon(Icons.check_circle_rounded, size: 30, color: cs.primary);
    final m = study.maxIndex(key_);
    if (m < 0) return Icon(Icons.play_circle_fill_rounded, size: 32, color: cs.onSurfaceVariant);
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(
          value: (m + 1) / total,
          strokeWidth: 3.5,
          backgroundColor: cs.surfaceContainerHighest,
        ),
        Text('${m + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Column(children: [
            Icon(icon, color: cs.primary, size: 22),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

/// Starred sentences; tap to jump back to that sentence, swipe to remove.
class _SavedTab extends StatelessWidget {
  const _SavedTab({required this.catalog});
  final List<Content> catalog;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = study.saved;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _Header('저장한 문장', '안 들렸거나 외우고 싶은 문장을 모아 다시 들어요'),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('학습 화면에서 ☆를 누르거나, 대본에서 문장을 길게 누르면 여기에 모입니다.',
                textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, height: 1.5)),
          ),
        for (final s in items)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Dismissible(
              key: ValueKey('${s.key}#${s.idx}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(18)),
                child: Icon(Icons.delete_outline_rounded, color: cs.onErrorContainer),
              ),
              onDismissed: (_) => study.toggleSaved(s),
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => openByKey(context, catalog, s.key, at: s.idx),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.35)),
                          if (s.ko != null) ...[
                            const SizedBox(height: 4),
                            Text(s.ko!, style: TextStyle(fontSize: 14, color: cs.primary)),
                          ],
                          const SizedBox(height: 6),
                          Text('${s.source} · 문장 ${s.idx + 1}',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ]),
                      ),
                      Icon(Icons.play_circle_fill_rounded, size: 32, color: cs.primary),
                    ]),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
