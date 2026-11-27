import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';


import '../data/content.dart';
import '../data/study_store.dart';
import '../player/background.dart';
import '../player/sentence_player.dart';
import '../youtube/pack.dart';

/// What the text area shows. Korean is a separate on/off toggle.
enum TextMode { blind, sentence, script, expressions }

const _modeLabels = {
  TextMode.blind: '듣기만',
  TextMode.sentence: '문장',
  TextMode.script: '대본',
  TextMode.expressions: '표현',
};

/// Study screen for one piece of content (TTS or YouTube).
/// Content on top, every playback control in a dock at the bottom.
class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.contentKey,
    required this.title,
    required this.subtitle,
    required this.createPlayer,
    this.header,
    this.expressions = const [],
    this.initialMode = TextMode.blind,
    this.startIndex,
    this.background = false,
  });

  /// Progress / saved-sentence key: `tts:CONTENT_ID` or `yt:PACK_FILE_NAME`.
  final String contentKey;
  final String title;
  final String subtitle;
  final SentencePlayer Function() createPlayer;

  /// Optional widget above the text (the YouTube video).
  final Widget Function(SentencePlayer)? header;
  final List<Expression> expressions;
  final TextMode initialMode;

  /// Open at this sentence instead of where the learner left off.
  final int? startIndex;

  /// Keep playing with the screen off (TTS only; never YouTube).
  final bool background;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final SentencePlayer p = widget.createPlayer();
  late TextMode mode = widget.initialMode;
  bool showKo = true;
  final _keys = <GlobalKey>[];
  int _followed = -1;
  int _savedIndex = -1;
  int _unsavedSeconds = 0;
  late final Timer _clock;

  bool get _hasKo => p.sentences.any((s) => s.ko != null);

  List<TextMode> get _modes => [
        TextMode.blind,
        TextMode.sentence,
        TextMode.script,
        if (widget.expressions.isNotEmpty) TextMode.expressions,
      ];

  @override
  void initState() {
    super.initState();
    _keys.addAll(List.generate(p.sentences.length, (_) => GlobalKey()));
    // Resume where the learner left off, with their repeat settings.
    p.index = (widget.startIndex ?? study.lastIndex(widget.contentKey)).clamp(0, p.sentences.length - 1);
    p.setRepeat(count: study.repeatCount, gapSeconds: study.gapSeconds);
    _saveProgress();
    p.addListener(_changed);
    if (widget.background) {
      ListenUpAudioHandler.instance?.attach(p, title: widget.title, subtitle: widget.subtitle);
      ListenUpAudioHandler.askNotificationPermission();
    }
    // Count listening time (only while audio is playing) for the streak.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (p.playing && !p.waiting) _unsavedSeconds++;
      if (_unsavedSeconds >= 15) _flushTime();
    });
  }

  void _flushTime() {
    study.addStudySeconds(_unsavedSeconds);
    _unsavedSeconds = 0;
  }

  void _saveProgress() {
    if (_savedIndex == p.index) return;
    _savedIndex = p.index;
    study.saveProgress(widget.contentKey,
        index: p.index, total: p.sentences.length, title: widget.title);
  }

  void _toggleSaved(int i) {
    final s = p.sentences[i];
    HapticFeedback.lightImpact();
    study.toggleSaved(SavedSentence(
      key: widget.contentKey,
      idx: i,
      text: s.text,
      ko: s.ko,
      source: widget.title,
      savedAt: DateTime.now(),
    ));
    setState(() {});
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _saveProgress();
    if (_followed != p.index && mode == TextMode.script) {
      _followed = p.index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[p.index].currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 250));
        }
      });
    }
  }

  @override
  void dispose() {
    _clock.cancel();
    _flushTime();
    ListenUpAudioHandler.instance?.detach(p);
    p.removeListener(_changed);
    p.dispose();
    super.dispose();
  }

  void _tap(VoidCallback f) {
    HapticFeedback.selectionClick();
    f();
  }

  void _setMode(TextMode m) {
    setState(() => mode = m);
    _followed = -1;
    _changed();
  }

  void _nextMode() => _setMode(_modes[(_modes.indexOf(mode) + 1) % _modes.length]);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): p.toggle,
        const SingleActivator(LogicalKeyboardKey.arrowRight): p.next,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): p.prev,
        const SingleActivator(LogicalKeyboardKey.keyR): p.repeat,
        const SingleActivator(LogicalKeyboardKey.keyS): p.cycleSpeed,
        const SingleActivator(LogicalKeyboardKey.keyT): _nextMode,
        const SingleActivator(LogicalKeyboardKey.keyK): () => setState(() => showKo = !showKo),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            toolbarHeight: 64,
            actions: [
              if (_hasKo)
                IconButton(
                  tooltip: showKo ? '해석 숨기기' : '해석 보기',
                  isSelected: showKo,
                  selectedIcon: const Icon(Icons.translate_rounded),
                  icon: const Icon(Icons.translate_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: showKo ? cs.primaryContainer : null,
                    foregroundColor: showKo ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                  ),
                  onPressed: () => setState(() => showKo = !showKo),
                ),
              const SizedBox(width: 8),
            ],
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(widget.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
            ]),
          ),
          body: Column(children: [
            if (widget.header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: ClipRRect(borderRadius: BorderRadius.circular(16), child: widget.header!(p)),
              ),
            _modeBar(cs),
            const SizedBox(height: 6),
            Expanded(child: _textArea(cs)),
            _Dock(player: p, onTap: _tap),
          ]),
        ),
      ),
    );
  }

  /// Text mode chips; all fit on one line (no icons, short labels).
  Widget _modeBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        for (final m in _modes)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              label: Text(_modeLabels[m]!, style: const TextStyle(fontWeight: FontWeight.w600)),
              selected: mode == m,
              onSelected: (_) => _setMode(m),
            ),
          ),
      ]),
    );
  }

  Widget _textArea(ColorScheme cs) {
    switch (mode) {
      case TextMode.blind:
        return _BlindView(player: p);
      case TextMode.sentence:
        return _SentenceView(
          player: p,
          showKo: showKo,
          saved: study.isSaved(widget.contentKey, p.index),
          onToggleSaved: () => _toggleSaved(p.index),
          onTapSentence: (i) => _tap(() => p.playSentence(i)),
        );
      case TextMode.expressions:
        return _ExpressionsView(expressions: widget.expressions);
      case TextMode.script:
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          itemCount: p.sentences.length,
          // Every tile is built so scrolling to the current one always works.
          cacheExtent: 100000,
          itemBuilder: (_, i) => KeyedSubtree(
            key: _keys[i],
            child: _ScriptTile(
              s: p.sentences[i],
              current: i == p.index,
              showKo: showKo,
              saved: study.isSaved(widget.contentKey, i),
              onToggleSaved: () => _toggleSaved(i),
              onTap: () => _tap(() => p.playSentence(i)),
            ),
          ),
        );
    }
  }
}

class _BlindView extends StatelessWidget {
  const _BlindView({required this.player});
  final SentencePlayer player;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
          child: Icon(player.playing ? Icons.graphic_eq_rounded : Icons.headphones_rounded,
              size: 48, color: cs.onPrimaryContainer),
        ),
        const SizedBox(height: 16),
        Text('문장 ${player.index + 1} / ${player.sentences.length}',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface)),
        const SizedBox(height: 6),
        Text('대본 없이 먼저 들어 보세요', style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

/// Speaker label shown above a sentence.
class _SpeakerChip extends StatelessWidget {
  const _SpeakerChip(this.name, {this.onDark = false});
  final String name;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: onDark ? cs.primary : cs.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(name,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: onDark ? cs.onPrimary : cs.onSecondaryContainer)),
    );
  }
}

/// One sentence, large and centred, with its neighbours faded above/below.
class _SentenceView extends StatelessWidget {
  const _SentenceView({
    required this.player,
    required this.showKo,
    required this.saved,
    required this.onToggleSaved,
    required this.onTapSentence,
  });
  final SentencePlayer player;
  final bool showKo;
  final bool saved;
  final VoidCallback onToggleSaved;
  final void Function(int) onTapSentence;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ss = player.sentences;
    final i = player.index;
    final s = ss[i];

    Widget neighbour(int j) => j < 0 || j >= ss.length
        ? const SizedBox(height: 22)
        : InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onTapSentence(j),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(ss[j].text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
            ),
          );

    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 12),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            neighbour(i - 1),
            const SizedBox(height: 6),
            Card(
              color: cs.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    if (s.speaker.isNotEmpty) _SpeakerChip(s.speaker),
                    const Spacer(),
                    Text('${i + 1} / ${ss.length}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: saved ? '저장 취소' : '이 문장 저장',
                      onPressed: onToggleSaved,
                      icon: Icon(saved ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: saved ? Colors.amber.shade700 : cs.onSurfaceVariant),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(s.text,
                        style: TextStyle(
                            fontSize: 24, height: 1.35, fontWeight: FontWeight.w700, color: cs.onSurface)),
                  ),
                  if (showKo && s.ko != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
                      child: Divider(height: 1, color: cs.outlineVariant),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(s.ko!,
                          style: TextStyle(
                              fontSize: 17, height: 1.45, color: cs.primary, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 6),
            neighbour(i + 1),
          ]),
        ),
      ),
    );
  }
}

class _ScriptTile extends StatelessWidget {
  const _ScriptTile({
    required this.s,
    required this.current,
    required this.showKo,
    required this.saved,
    required this.onToggleSaved,
    required this.onTap,
  });
  final Sentence s;
  final bool current;
  final bool showKo;
  final bool saved;
  final VoidCallback onToggleSaved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: current ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onToggleSaved,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border(
                left: BorderSide(color: current ? cs.primary : Colors.transparent, width: 4),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (s.speaker.isNotEmpty || saved) ...[
                Row(children: [
                  if (s.speaker.isNotEmpty) _SpeakerChip(s.speaker, onDark: current),
                  const Spacer(),
                  if (saved) Icon(Icons.star_rounded, size: 18, color: Colors.amber.shade700),
                ]),
                const SizedBox(height: 6),
              ],
              Text(s.text,
                  style: TextStyle(
                      fontSize: 18,
                      height: 1.35,
                      fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                      color: current ? cs.onPrimaryContainer : cs.onSurface)),
              if (showKo && s.ko != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(s.ko!,
                      style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: current ? cs.onPrimaryContainer.withValues(alpha: 0.85) : cs.onSurfaceVariant)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ExpressionsView extends StatelessWidget {
  const _ExpressionsView({required this.expressions});
  final List<Expression> expressions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: expressions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final e = expressions[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.en, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(height: 4),
              Text(e.ko, style: TextStyle(fontSize: 16, color: cs.primary, fontWeight: FontWeight.w500)),
              if (e.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(e.note, style: TextStyle(fontSize: 13, height: 1.4, color: cs.onSurfaceVariant)),
              ],
            ]),
          ),
        );
      },
    );
  }
}

/// Bottom control dock: sentence slider + big transport buttons.
class _Dock extends StatefulWidget {
  const _Dock({required this.player, required this.onTap});
  final SentencePlayer player;
  final void Function(VoidCallback) onTap;

  @override
  State<_Dock> createState() => _DockState();
}

class _DockState extends State<_Dock> {
  /// Sentence under the finger while dragging the slider.
  int? _drag;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = widget.player;
    final onTap = widget.onTap;
    final n = p.sentences.length;
    final shown = _drag ?? p.index;
    final status = p.waiting
        ? '따라 말해 보세요'
        : p.single
            ? '한 문장 재생'
            : p.playing
                ? (p.repeatCount > 1 ? '반복 ${p.repeatNo}/${p.repeatCount}' : '이어서 재생 중')
                : '정지';
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text('문장 ${shown + 1} / $n',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface)),
              const SizedBox(width: 10),
              Icon(
                  p.waiting
                      ? Icons.record_voice_over_rounded
                      : (p.playing ? Icons.volume_up_rounded : Icons.pause_circle_outline_rounded),
                  size: 16,
                  color: p.waiting ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        color: p.waiting ? cs.primary : cs.onSurfaceVariant,
                        fontWeight: p.waiting ? FontWeight.w700 : FontWeight.w400)),
              ),
              _RepeatButton(player: p),
            ]),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              ),
              child: Slider(
                value: shown.toDouble(),
                min: 0,
                max: (n - 1).clamp(1, 1 << 20).toDouble(),
                divisions: n > 1 ? n - 1 : null,
                label: '${shown + 1}',
                onChanged: n > 1 ? (v) => setState(() => _drag = v.round()) : null,
                onChangeEnd: n > 1
                    ? (v) {
                        setState(() => _drag = null);
                        p.playSentence(v.round());
                      }
                    : null,
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _SpeedButton(player: p, onTap: onTap),
              IconButton(
                iconSize: 36,
                tooltip: '이전 문장',
                onPressed: () => onTap(p.prev),
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              SizedBox(
                width: 76,
                height: 76,
                child: IconButton.filled(
                  iconSize: 44,
                  tooltip: p.playing ? '일시정지' : '재생',
                  onPressed: () => onTap(p.toggle),
                  icon: Icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
              ),
              IconButton(
                iconSize: 36,
                tooltip: '다음 문장',
                onPressed: () => onTap(p.next),
                icon: const Icon(Icons.skip_next_rounded),
              ),
              SizedBox(
                width: 56,
                height: 56,
                child: IconButton.filledTonal(
                  iconSize: 28,
                  tooltip: '이 문장 다시',
                  onPressed: () => onTap(p.repeat),
                  icon: const Icon(Icons.replay_rounded),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.player, required this.onTap});
  final SentencePlayer player;
  final void Function(VoidCallback) onTap;

  @override
  Widget build(BuildContext context) {
    final s = player.speed;
    final label = s == s.roundToDouble() ? '${s.toStringAsFixed(1)}x' : '${s}x';
    return SizedBox(
      width: 64,
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
        onPressed: () => onTap(player.cycleSpeed),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

String _gapLabel(int g) => g < 0 ? '문장만큼' : '$g초';

/// Shows the current repeat setting; opens the settings sheet.
class _RepeatButton extends StatelessWidget {
  const _RepeatButton({required this.player});
  final SentencePlayer player;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final on = p.repeatCount > 1 || p.gapSeconds != 0;
    final label = on ? '${p.repeatCount}회 · 멈춤 ${_gapLabel(p.gapSeconds)}' : '반복 설정';
    return TextButton.icon(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        backgroundColor: on ? Theme.of(context).colorScheme.primaryContainer : null,
      ),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _RepeatSheet(player: p),
      ),
      icon: const Icon(Icons.repeat_rounded, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _RepeatSheet extends StatefulWidget {
  const _RepeatSheet({required this.player});
  final SentencePlayer player;

  @override
  State<_RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<_RepeatSheet> {
  late int repeat = widget.player.repeatCount;
  late int gap = widget.player.gapSeconds;

  void _apply() {
    widget.player.setRepeat(count: repeat, gapSeconds: gap);
    study.setPlayback(repeat: repeat, gap: gap);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget title(String t, String sub) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(sub, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ]),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('반복 재생 설정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          title('문장마다 반복', '재생 버튼으로 이어 들을 때 한 문장을 몇 번 들을지'),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 1, label: Text('1회')),
              ButtonSegment(value: 2, label: Text('2회')),
              ButtonSegment(value: 3, label: Text('3회')),
              ButtonSegment(value: 5, label: Text('5회')),
            ],
            selected: {repeat},
            onSelectionChanged: (v) => setState(() {
              repeat = v.first;
              _apply();
            }),
          ),
          title('문장 사이 멈춤', '따라 말할 시간. "문장만큼"은 방금 들은 문장 길이만큼 쉬어요'),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('없음')),
              ButtonSegment(value: 1, label: Text('1초')),
              ButtonSegment(value: 2, label: Text('2초')),
              ButtonSegment(value: 3, label: Text('3초')),
              ButtonSegment(value: -1, label: Text('문장만큼')),
            ],
            selected: {gap},
            onSelectionChanged: (v) => setState(() {
              gap = v.first;
              _apply();
            }),
          ),
          const SizedBox(height: 16),
          Text('이전·다음·다시 버튼과 문장 누르기는 항상 한 번만 재생합니다.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
