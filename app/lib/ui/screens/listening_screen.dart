import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/content.dart';
import '../nav.dart';
import '../theme.dart';

enum RotateMode { sentence, speed }

/// What the text area shows. Cycled with ↻ long-press (or T).
enum TextMode { blind, script, scriptKo }

/// "Now Listening": sentence-by-sentence playback controlled by the wheel.
///
/// Wheel mapping (docs/DESIGN.md §3):
///   rotate            → previous/next sentence (or speed in speed mode)
///   center            → play / pause (continuous)
///   center long-press → toggle rotate mode: sentence ↔ speed
///   ⏮ / ⏭             → previous / next sentence
///   ↻                 → repeat current sentence
///   ↻ long-press      → text: blind → script → script + Korean → blind
class ListeningScreen extends AppScreen {
  ListeningScreen(this.content) {
    _player.positionUpdater = TimerPositionUpdater(
      interval: const Duration(milliseconds: 40),
      getPosition: _player.getCurrentPosition,
    );
    _subs.add(_player.onPositionChanged.listen(_onPosition));
    _subs.add(_player.onPlayerComplete.listen((_) {
      playing = false;
      position = content.duration;
      refresh();
    }));
    _ready = _player.setSource(AssetSource(content.audioAsset));
  }

  final Content content;
  final _player = AudioPlayer();
  final _subs = <StreamSubscription>[];
  late final Future<void> _ready;

  int index = 0;
  bool playing = false;
  bool single = false; // stop at the end of the current sentence
  double speed = 1.0;
  RotateMode mode = RotateMode.sentence;
  TextMode textMode = TextMode.blind;
  final _keys = <GlobalKey>[];
  int _scrolledTo = -1;
  Duration position = Duration.zero;

  List<Sentence> get _s => content.sentences;

  @override
  String get title => 'Now Listening';

  void _onPosition(Duration p) {
    position = p;
    if (single && p >= _s[index].end) {
      single = false;
      playing = false;
      _player.pause();
    } else if (!single) {
      var i = 0;
      while (i + 1 < _s.length && _s[i + 1].start <= p) {
        i++;
      }
      index = i;
    }
    refresh();
  }

  Future<void> _playSentence(int i) async {
    index = i.clamp(0, _s.length - 1);
    single = true;
    playing = true;
    refresh();
    await _ready;
    await _player.seek(_s[index].start);
    await _player.setPlaybackRate(speed);
    await _player.resume();
  }

  @override
  Future<void> onCenter() async {
    await _ready;
    if (playing) {
      playing = false;
      await _player.pause();
    } else {
      single = false;
      playing = true;
      if (position >= content.duration - const Duration(milliseconds: 100)) {
        index = 0;
        await _player.seek(Duration.zero);
      }
      await _player.setPlaybackRate(speed);
      await _player.resume();
    }
    refresh();
  }

  @override
  void onRotate(int steps) {
    if (mode == RotateMode.sentence) {
      _moveTo(index + steps);
    } else {
      speed = ((speed * 10 + steps).clamp(5, 15)) / 10;
      _player.setPlaybackRate(speed);
      refresh();
    }
  }

  @override
  void onCenterLong() {
    mode = mode == RotateMode.sentence ? RotateMode.speed : RotateMode.sentence;
    refresh();
  }

  @override
  void onPrev() => _moveTo(index - 1);
  @override
  void onNext() => _moveTo(index + 1);

  /// Jump to another sentence. Past the first or last sentence nothing
  /// happens (no replay), so ⏭ on the last sentence doesn't restart it.
  void _moveTo(int target) {
    final t = target.clamp(0, _s.length - 1);
    if (t == index && target != index) {
      HapticFeedback.heavyImpact();
      return;
    }
    _playSentence(t);
  }
  @override
  void onBottom() => _playSentence(index);

  @override
  void onBottomLong() {
    textMode = TextMode.values[(textMode.index + 1) % TextMode.values.length];
    _scrolledTo = -1;
    refresh();
  }

  /// Keep the current sentence in view in the script list.
  void _followCurrent() {
    if (_scrolledTo == index) return;
    _scrolledTo = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = index < _keys.length ? _keys[index].currentContext : null;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.35, duration: const Duration(milliseconds: 200));
      }
    });
  }

  Widget _script(Palette pal) {
    if (_keys.length != _s.length) {
      _keys
        ..clear()
        ..addAll(List.generate(_s.length, (_) => GlobalKey()));
    }
    _followCurrent();
    final withKo = textMode == TextMode.scriptKo;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in _s)
            GestureDetector(
              key: _keys[s.idx],
              onTap: () => _playSentence(s.idx),
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: s.idx == index ? Palette.accentBottom.withValues(alpha: 0.14) : null,
                  borderRadius: BorderRadius.circular(6),
                  border: Border(
                    left: BorderSide(
                      color: s.idx == index ? Palette.accentBottom : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: '${s.speaker}  ',
                            style: TextStyle(
                                color: pal.subtext, fontSize: 12, fontWeight: FontWeight.w700)),
                        TextSpan(text: s.text),
                      ]),
                      style: TextStyle(
                        color: pal.text,
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: s.idx == index ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (withKo && s.ko != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(s.ko!,
                            style: TextStyle(color: pal.subtext, fontSize: 14, height: 1.3)),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = Palette.of(context);
    final total = content.duration.inMilliseconds;
    final frac = total == 0 ? 0.0 : (position.inMilliseconds / total).clamp(0.0, 1.0);
    final small = TextStyle(color: pal.subtext, fontSize: 13);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text('L${content.level} · ${content.track == 'news' ? 'News' : 'Daily'}',
                  style: small),
            ),
            _Chip('${speed.toStringAsFixed(1)}x', active: mode == RotateMode.speed),
          ]),
          const SizedBox(height: 4),
          Text(content.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: pal.text, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text('Sentence ${index + 1} of ${_s.length}',
              textAlign: TextAlign.center, style: TextStyle(color: pal.text, fontSize: 14)),
          const SizedBox(height: 6),
          Row(children: [
            Text(_fmt(position), style: small),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 7,
                  backgroundColor: pal.screenBorder.withValues(alpha: 0.5),
                  valueColor: const AlwaysStoppedAnimation(Palette.accentBottom),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(_fmt(content.duration), style: small),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: textMode == TextMode.blind
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(playing ? Icons.graphic_eq_rounded : Icons.headphones_rounded,
                          color: pal.subtext, size: 34),
                      const SizedBox(height: 6),
                      Text('Blind listening · hold ↻ for script', style: small),
                    ]),
                  )
                : _script(pal),
          ),
          const SizedBox(height: 6),
          Text(
            '${const ['Blind', 'Script', 'Script + 해석'][textMode.index]} · hold ↻ to change  |  '
            '${mode == RotateMode.sentence ? 'hold center: speed' : 'hold center: sentences'}',
            textAlign: TextAlign.center,
            style: small.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.active});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final pal = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: active ? Palette.accentBottom : Colors.transparent,
        border: Border.all(color: active ? Palette.accentBottom : pal.screenBorder),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: active ? Colors.white : pal.subtext, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
