import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/content.dart';

/// Sentence-based playback shared by TTS content and YouTube packs.
/// The UI only talks to this class.
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

  List<double> get speeds;

  // ---- engine hooks ----
  Future<void> engineSeek(Duration to);
  Future<void> enginePlay();
  Future<void> enginePause();
  Future<void> engineSpeed(double s);

  /// Called by implementations with the current playback position.
  void onPosition(Duration p) {
    final cur = sentences[index];
    // Ignore stale positions reported before a seek has landed.
    if (single &&
        (p < cur.start - const Duration(milliseconds: 400) ||
            p > cur.end + const Duration(milliseconds: 1500))) {
      return;
    }
    if (single && p >= cur.end) {
      single = false;
      playing = false;
      enginePause();
    } else if (!single) {
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
    notifyListeners();
  }

  /// Called by implementations when the media ends.
  void onComplete() {
    playing = false;
    if (!single) finished = true;
    single = false;
    notifyListeners();
  }

  // ---- actions ----
  Future<void> playSentence(int i) async {
    index = i.clamp(0, sentences.length - 1);
    single = true;
    finished = false;
    playing = true;
    notifyListeners();
    await engineSeek(sentences[index].start);
    await engineSpeed(speed);
    await enginePlay();
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
      playing = false;
      notifyListeners();
      await enginePause();
      return;
    }
    if (finished) index = 0;
    finished = false;
    single = false;
    playing = true;
    notifyListeners();
    await engineSeek(sentences[index].start);
    await engineSpeed(speed);
    await enginePlay();
  }

  Future<void> cycleSpeed() async {
    final i = speeds.indexOf(speed);
    speed = speeds[(i + 1) % speeds.length];
    notifyListeners();
    await engineSpeed(speed);
  }
}
