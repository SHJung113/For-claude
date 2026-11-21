import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/content.dart';
import '../player/sentence_player.dart';
import '../youtube/pack.dart';

enum TextMode { blind, script, translation, expressions }

/// Study screen for one piece of content (TTS or YouTube).
/// Text area on top, every control in a dock at the bottom for one thumb.
class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.createPlayer,
    this.header,
    this.expressions = const [],
    this.initialMode = TextMode.blind,
  });

  final String title;
  final String subtitle;
  final SentencePlayer Function() createPlayer;

  /// Optional widget above the text (the YouTube video).
  final Widget Function(SentencePlayer)? header;
  final List<Expression> expressions;
  final TextMode initialMode;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final SentencePlayer p = widget.createPlayer();
  late TextMode mode = widget.initialMode;
  final _keys = <GlobalKey>[];
  int _followed = -1;

  @override
  void initState() {
    super.initState();
    _keys.addAll(List.generate(p.sentences.length, (_) => GlobalKey()));
    p.addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (_followed != p.index && mode != TextMode.blind && mode != TextMode.expressions) {
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
    p.removeListener(_changed);
    p.dispose();
    super.dispose();
  }

  void _tap(VoidCallback f) {
    HapticFeedback.selectionClick();
    f();
  }

  List<TextMode> get _modes => [
        TextMode.blind,
        TextMode.script,
        TextMode.translation,
        if (widget.expressions.isNotEmpty) TextMode.expressions,
      ];

  void _nextMode() {
    final m = _modes;
    setState(() => mode = m[(m.indexOf(mode) + 1) % m.length]);
    _followed = -1;
    _changed();
  }

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
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(widget.subtitle,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
            ]),
          ),
          body: Column(children: [
            if (widget.header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: ClipRRect(borderRadius: BorderRadius.circular(16), child: widget.header!(p)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _modeSelector(),
            ),
            const SizedBox(height: 8),
            Expanded(child: _textArea(cs)),
            _Dock(player: p, onTap: _tap),
          ]),
        ),
      ),
    );
  }

  Widget _modeSelector() {
    const labels = {
      TextMode.blind: '듣기만',
      TextMode.script: '대본',
      TextMode.translation: '해석',
      TextMode.expressions: '표현',
    };
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<TextMode>(
        showSelectedIcon: false,
        segments: [
          for (final m in _modes) ButtonSegment(value: m, label: Text(labels[m]!)),
        ],
        selected: {mode},
        onSelectionChanged: (s) {
          setState(() => mode = s.first);
          _followed = -1;
          _changed();
        },
      ),
    );
  }

  Widget _textArea(ColorScheme cs) {
    switch (mode) {
      case TextMode.blind:
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(p.playing ? Icons.graphic_eq_rounded : Icons.headphones_rounded,
                size: 56, color: cs.primary),
            const SizedBox(height: 12),
            Text('문장 ${p.index + 1} / ${p.sentences.length}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface)),
            const SizedBox(height: 6),
            Text('대본 없이 먼저 들어 보세요', style: TextStyle(color: cs.onSurfaceVariant)),
          ]),
        );
      case TextMode.expressions:
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: widget.expressions.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final e = widget.expressions[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.en, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(e.ko, style: const TextStyle(fontSize: 15)),
                  if (e.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(e.note, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  ],
                ]),
              ),
            );
          },
        );
      case TextMode.script:
      case TextMode.translation:
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(children: [for (final s in p.sentences) _sentenceTile(s, cs)]),
        );
    }
  }

  Widget _sentenceTile(Sentence s, ColorScheme cs) {
    final cur = s.idx == p.index;
    return Padding(
      key: _keys[s.idx],
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: cur ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _tap(() => p.playSentence(s.idx)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 64,
                child: Text(s.speaker,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.9,
                        fontWeight: FontWeight.w700,
                        color: cur ? cs.onPrimaryContainer : cs.onSurfaceVariant)),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.text,
                      style: TextStyle(
                          fontSize: 17,
                          height: 1.35,
                          fontWeight: cur ? FontWeight.w600 : FontWeight.w400,
                          color: cur ? cs.onPrimaryContainer : cs.onSurface)),
                  if (mode == TextMode.translation && s.ko != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(s.ko!,
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.35,
                              color: cur
                                  ? cs.onPrimaryContainer.withValues(alpha: 0.8)
                                  : cs.onSurfaceVariant)),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Bottom control dock: sentence slider + big transport buttons.
class _Dock extends StatelessWidget {
  const _Dock({required this.player, required this.onTap});
  final SentencePlayer player;
  final void Function(VoidCallback) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = player;
    final n = p.sentences.length;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text('문장 ${p.index + 1} / $n',
                  style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
              const Spacer(),
              Text(p.single ? '한 문장 재생' : (p.playing ? '이어서 재생' : '정지'),
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ]),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              ),
              child: Slider(
                value: p.index.toDouble(),
                min: 0,
                max: (n - 1).clamp(1, 1 << 20).toDouble(),
                divisions: n > 1 ? n - 1 : null,
                onChanged: n > 1 ? (v) => p.playSentence(v.round()) : null,
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _SpeedButton(player: p, onTap: onTap),
              IconButton(
                iconSize: 34,
                tooltip: '이전 문장',
                onPressed: () => onTap(p.prev),
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              SizedBox(
                width: 76,
                height: 76,
                child: IconButton.filled(
                  iconSize: 42,
                  tooltip: p.playing ? '일시정지' : '재생',
                  onPressed: () => onTap(p.toggle),
                  icon: Icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
              ),
              IconButton(
                iconSize: 34,
                tooltip: '다음 문장',
                onPressed: () => onTap(p.next),
                icon: const Icon(Icons.skip_next_rounded),
              ),
              IconButton.filledTonal(
                iconSize: 28,
                tooltip: '이 문장 다시',
                onPressed: () => onTap(p.repeat),
                icon: const Icon(Icons.replay_rounded),
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
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(56, 44)),
        onPressed: () => onTap(player.cycleSpeed),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
