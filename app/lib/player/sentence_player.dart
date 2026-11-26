import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/content.dart';

/// Sentence-based playback shared by TTS content and YouTube packs.
/// The UI only talks to this class.
///
/// Modes:
/// * single  – play one sentence and stop (⏮ ⏭ ↻, tapping a sentence)
/// * flowing – continuous play straight through the media (repeat 1, no pause)
/// * stepped – continuous play sentence by sentence, each repeated
///             [repeatCount] times with a pause between ([gapSeconds])
abstract class SentencePlayer extends ChangeNotifier {
  SentencePlayer(this.sentences);

  final List<Sentence> sentences;

  int index = 0;
  bool playing = false;
  double speed = 1.0;

  /// Stop at the end of the current sentence instead of continuing.
  bool single = false;

  /// Reached the end of the last sentence while playing through.
  bool finished = false;

  /// Repeat / pause settings for continuous play.
  int repeatCount = 1;

  /// Seconds to pause after each sentence; -1 = the sentence's own length.
  int gapSeconds = 0;

  /// Which play of the current sentence this is (1-based) in stepped mode.
  int repeatNo = 1;

  /// Paused between sentences in stepped mode (time to shadow).
  bool waiting = false;
  Timer? _gapTimer;

  /// When the app last told the engine to play/pause/seek. Engine state
  /// reports shortly after a command are stale and must not override it.
  DateTime lastCommand = DateTime.fromMillisecondsSinceEpoch(0);

  List<double> get speeds;

  bool get _stepped => repeatCount > 1 || gapSeconds != 0;

  // ---- engine hooks ----
  Future<void> engineSeek(Duration to);
  Future<void> enginePlay();
  Future<void> enginePause();
  Future<void> engineSpeed(double s);

  /// Notifies only when something the UI shows has changed
  /// (positions arrive every ~40-150 ms).
  void _update(void Function() change) {
    final before = (index, playing, single, finished, waiting, repeatNo);
    change();
    if (before != (index, playing, single, finished, waiting, repeatNo)) notifyListeners();
  }

  /// Called by implementations with the current playback position.
  void onPosition(Duration p) {
    // While paused the engine may still report positions (e.g. 0 right after
    // loading); they must not move the current sentence (resume position).
    if (waiting || !playing) return;
    final cur = sentences[index];
    final pinned = single || _stepped;
    // Ignore stale positions reported before a seek has landed.
    if (pinned &&
        (p < cur.start - const Duration(milliseconds: 400) ||
            p > cur.end + const Duration(milliseconds: 1500))) {
      return;
    }
    _update(() {
      if (single) {
        if (p >= cur.end) {
          single = false;
          playing = false;
          enginePause();
        }
      } else if (_stepped) {
        if (p >= cur.end) _sentenceEnded();
      } else {
        var i = index;
        while (i + 1 < sentences.length && sentences[i + 1].start <= p) {
          i++;
        }
        while (i > 0 && sentences[i].start > p) {
          i--;
        }
        index = i;
        if (p >= sentences.last.end) {
          playing = false;
          finished = true;
          enginePause();
        }
      }
    });
  }

  /// Stepped mode: pause, then repeat the sentence or move on.
  void _sentenceEnded() {
    lastCommand = DateTime.now();
    enginePause();
    final cur = sentences[index];
    final gap = gapSeconds < 0 ? cur.end - cur.start : Duration(seconds: gapSeconds);
    waiting = true;
    _gapTimer?.cancel();
    _gapTimer = Timer(gap, () async {
      waiting = false;
      if (!playing) return notifyListeners();
      if (repeatNo < repeatCount) {
        repeatNo++;
      } else if (index + 1 < sentences.length) {
        repeatNo = 1;
        index++;
      } else {
        repeatNo = 1;
        playing = false;
        finished = true;
        return notifyListeners();
      }
      notifyListeners();
      await _start(sentences[index].start);
    });
  }

  Future<void> _start(Duration at) async {
    lastCommand = DateTime.now();
    await engineSeek(at);
    await engineSpeed(speed);
    await enginePlay();
  }

  void _cancelGap() {
    _gapTimer?.cancel();
    waiting = false;
  }

  /// Called by implementations when the media ends.
  void onComplete() => _update(() {
        if (waiting) return; // the stepped sequence already handles this end
        if (playing && _stepped && !single) {
          _sentenceEnded();
          return;
        }
        playing = false;
        if (!single) finished = true;
        single = false;
      });

  /// The engine was started or stopped by something other than the app
  /// (e.g. a tap on the video). Keeps the UI in sync.
  void onEnginePlaying(bool isPlaying) {
    if (waiting) return;
    if (DateTime.now().difference(lastCommand) < const Duration(milliseconds: 1200)) return;
    _update(() {
      if (isPlaying && !playing) {
        playing = true;
        single = false;
      } else if (!isPlaying && playing) {
        playing = false;
        single = false;
      }
    });
  }

  // ---- actions ----
  Future<void> playSentence(int i) async {
    _cancelGap();
    index = i.clamp(0, sentences.length - 1);
    single = true;
    finished = false;
    playing = true;
    repeatNo = 1;
    notifyListeners();
    await _start(sentences[index].start);
  }

  /// Moves to another sentence; past the first/last one nothing happens.
  void moveTo(int target) {
    final t = target.clamp(0, sentences.length - 1);
    if (t == index && target != index) {
      HapticFeedback.heavyImpact();
      return;
    }
    playSentence(t);
  }

  void next() => moveTo(index + 1);
  void prev() => moveTo(index - 1);
  void repeat() => playSentence(index);

  /// Play continuously from the current sentence, or pause.
  Future<void> toggle() async {
    if (playing) {
      lastCommand = DateTime.now();
      _cancelGap();
      playing = false;
      single = false;
      notifyListeners();
      await enginePause();
      return;
    }
    _cancelGap();
    if (finished) index = 0;
    finished = false;
    single = false;
    playing = true;
    repeatNo = 1;
    notifyListeners();
    await _start(sentences[index].start);
  }

  Future<void> cycleSpeed() async {
    final i = speeds.indexOf(speed);
    speed = speeds[(i + 1) % speeds.length];
    notifyListeners();
    await engineSpeed(speed);
  }

  void setRepeat({required int count, required int gapSeconds}) {
    repeatCount = count;
    this.gapSeconds = gapSeconds;
    if (repeatNo > count) repeatNo = 1;
    notifyListeners();
  }

  @override
  void dispose() {
    _gapTimer?.cancel();
    super.dispose();
  }
}
