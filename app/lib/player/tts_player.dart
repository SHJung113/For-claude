import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../data/content.dart';
import 'sentence_player.dart';

/// Plays a bundled TTS content file.
class TtsPlayer extends SentencePlayer {
  TtsPlayer(this.content) : super(content.sentences) {
    _player.positionUpdater = TimerPositionUpdater(
      interval: const Duration(milliseconds: 40),
      getPosition: _player.getCurrentPosition,
    );
    _subs.add(_player.onPositionChanged.listen(onPosition));
    _subs.add(_player.onPlayerComplete.listen((_) => onComplete()));
    _ready = _player.setSource(AssetSource(content.audioAsset));
  }

  final Content content;
  final _player = AudioPlayer();
  final _subs = <StreamSubscription>[];
  late final Future<void> _ready;

  @override
  List<double> get speeds => const [0.5, 0.75, 0.9, 1.0, 1.25];

  @override
  Future<void> engineSeek(Duration to) async {
    await _ready;
    await _player.seek(to);
  }

  @override
  Future<void> enginePlay() async {
    await _ready;
    await _player.resume();
  }

  @override
  Future<void> enginePause() => _player.pause();

  @override
  Future<void> engineSpeed(double s) => _player.setPlaybackRate(s);

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
