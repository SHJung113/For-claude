import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../data/content.dart';
import '../../youtube/pack.dart';
import '../nav.dart';
import '../theme.dart';
import 'menu_screen.dart';

/// YouTube is played only through the official embedded player (no
/// downloads). Android and web only: the embedded player has no Windows
/// support.
bool get youtubeSupported => kIsWeb || defaultTargetPlatform == TargetPlatform.android;

/// YouTube menu: imported learning packs + "import" action.
class YouTubeHome extends MenuScreen {
  YouTubeHome() : super('YouTube', []) {
    _reload();
  }

  String? _message;

  Future<void> _reload() async {
    final packs = await PackStore.list();
    items
      ..clear()
      ..add(MenuItem('+ 학습 팩 가져오기', action: _import))
      ..addAll([
        for (final p in packs)
          MenuItem(p.title, detail: '≈L${p.estimatedLevel}', open: () => YouTubeScreen(p)),
      ]);
    refresh();
  }

  Future<void> _import() async {
    try {
      final p = await PackStore.importFromPicker();
      if (p != null) _message = '"${p.title}" 가져옴';
    } on FormatException catch (e) {
      _message = e.message;
    } catch (e) {
      _message = '가져오기 실패: $e';
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final pal = Palette.of(context);
    if (!youtubeSupported) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('YouTube 학습은 Android 폰에서 사용할 수 있습니다.',
              textAlign: TextAlign.center, style: TextStyle(color: pal.subtext)),
        ),
      );
    }
    return Column(children: [
      Expanded(child: super.build(context)),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(_message!, style: TextStyle(color: pal.subtext, fontSize: 12)),
        ),
    ]);
  }
}

enum _TextMode { blind, script, scriptKo, expressions }

enum _Rotate { sentence, speed }

/// Sentence-by-sentence study of one YouTube learning pack.
/// Same controls as the TTS player: rotate = sentence, center = play/pause,
/// hold center = speed mode, ↻ = repeat sentence, hold ↻ = text mode.
class YouTubeScreen extends AppScreen {
  YouTubeScreen(this.pack)
      : _yt = YoutubePlayerController.fromVideoId(
          videoId: pack.videoId,
          startSeconds: pack.sentences.first.start.inMilliseconds / 1000,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: false,
            strictRelatedVideos: true,
            playsInline: true,
          ),
        ) {
    _timer = Timer.periodic(const Duration(milliseconds: 150), (_) => _tick());
  }

  final YouTubePack pack;
  final YoutubePlayerController _yt;
  late final Timer _timer;

  int index = 0;
  bool playing = false;
  bool single = false;
  double speed = 1.0;
  _Rotate _rotate = _Rotate.sentence;
  _TextMode _textMode = _TextMode.scriptKo;
  final _keys = <GlobalKey>[];
  int _scrolledTo = -1;
  bool _busy = false;

  static const _speeds = [0.5, 0.75, 1.0, 1.25];

  List<Sentence> get _s => pack.sentences;

  @override
  String get title => 'YouTube';

  Future<void> _tick() async {
    if (!playing || _busy) return;
    _busy = true;
    try {
      final t = await _yt.currentTime;
      final ms = (t * 1000).round();
      if (single) {
        if (ms >= _s[index].end.inMilliseconds) {
          single = false;
          playing = false;
          await _yt.pauseVideo();
        }
      } else {
        var i = index;
        while (i + 1 < _s.length && _s[i + 1].start.inMilliseconds <= ms) {
          i++;
        }
        while (i > 0 && _s[i].start.inMilliseconds > ms) {
          i--;
        }
        if (ms >= _s.last.end.inMilliseconds) {
          playing = false;
          await _yt.pauseVideo();
        }
        index = i;
      }
      refresh();
    } catch (_) {
      // player not ready yet
    } finally {
      _busy = false;
    }
  }

  Future<void> _playSentence(int i) async {
    index = i.clamp(0, _s.length - 1);
    single = true;
    playing = true;
    refresh();
    await _yt.seekTo(seconds: _s[index].start.inMilliseconds / 1000, allowSeekAhead: true);
    await _yt.playVideo();
  }

  void _moveTo(int target) {
    final t = target.clamp(0, _s.length - 1);
    if (t == index && target != index) {
      HapticFeedback.heavyImpact();
      return;
    }
    _playSentence(t);
  }

  @override
  Future<void> onCenter() async {
    if (playing) {
      playing = false;
      await _yt.pauseVideo();
    } else {
      single = false;
      playing = true;
      await _yt.seekTo(seconds: _s[index].start.inMilliseconds / 1000, allowSeekAhead: true);
      await _yt.playVideo();
    }
    refresh();
  }

  @override
  void onRotate(int steps) {
    if (_rotate == _Rotate.sentence) {
      _moveTo(index + steps);
    } else {
      final i = (_speeds.indexOf(speed) + steps).clamp(0, _speeds.length - 1);
      speed = _speeds[i];
      _yt.setPlaybackRate(speed);
      refresh();
    }
  }

  @override
  void onCenterLong() {
    _rotate = _rotate == _Rotate.sentence ? _Rotate.speed : _Rotate.sentence;
    refresh();
  }

  @override
  void onPrev() => _moveTo(index - 1);
  @override
  void onNext() => _moveTo(index + 1);
  @override
  void onBottom() => _playSentence(index);

  @override
  void onBottomLong() {
    _textMode = _TextMode.values[(_textMode.index + 1) % _TextMode.values.length];
    _scrolledTo = -1;
    refresh();
  }

  @override
  void dispose() {
    _timer.cancel();
    _yt.close();
  }

  void _follow() {
    if (_scrolledTo == index) return;
    _scrolledTo = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = index < _keys.length ? _keys[index].currentContext : null;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, alignment: 0.3, duration: const Duration(milliseconds: 200));
      }
    });
  }

  Widget _body(Palette pal) {
    switch (_textMode) {
      case _TextMode.blind:
        return Center(
          child: Text('Blind listening · hold ↻ for script',
              style: TextStyle(color: pal.subtext, fontSize: 13)),
        );
      case _TextMode.expressions:
        return ListView(children: [
          for (final e in pack.expressions)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.en,
                    style: TextStyle(color: pal.text, fontSize: 16, fontWeight: FontWeight.w700)),
                Text(e.ko, style: TextStyle(color: pal.text, fontSize: 14)),
                if (e.note.isNotEmpty)
                  Text(e.note, style: TextStyle(color: pal.subtext, fontSize: 12)),
              ]),
            ),
        ]);
      case _TextMode.script:
      case _TextMode.scriptKo:
        if (_keys.length != _s.length) {
          _keys
            ..clear()
            ..addAll(List.generate(_s.length, (_) => GlobalKey()));
        }
        _follow();
        return SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final s in _s)
              GestureDetector(
                key: _keys[s.idx],
                onTap: () => _playSentence(s.idx),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: s.idx == index ? Palette.accentBottom.withValues(alpha: 0.14) : null,
                    borderRadius: BorderRadius.circular(6),
                    border: Border(
                      left: BorderSide(
                          color: s.idx == index ? Palette.accentBottom : Colors.transparent,
                          width: 3),
                    ),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: s.idx == index ? FontWeight.w600 : FontWeight.w400),
                    ),
                    if (_textMode == _TextMode.scriptKo && s.ko != null)
                      Text(s.ko!, style: TextStyle(color: pal.subtext, fontSize: 13, height: 1.3)),
                  ]),
                ),
              ),
          ]),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = Palette.of(context);
    final small = TextStyle(color: pal.subtext, fontSize: 12);
    const modes = ['Blind', 'Script', 'Script + 해석', '표현'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: YoutubePlayer(controller: _yt, aspectRatio: 16 / 9),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Text('${pack.title} · ≈L${pack.estimatedLevel} · ${index + 1}/${_s.length}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: pal.text, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: _rotate == _Rotate.speed ? Palette.accentBottom : null,
              border: Border.all(
                  color: _rotate == _Rotate.speed ? Palette.accentBottom : pal.screenBorder),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('${speed}x',
                style: TextStyle(
                    color: _rotate == _Rotate.speed ? Colors.white : pal.subtext,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        Expanded(child: _body(pal)),
        Text('${modes[_textMode.index]} · hold ↻ to change', textAlign: TextAlign.center, style: small),
      ]),
    );
  }
}
