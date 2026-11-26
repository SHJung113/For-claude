import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../youtube/pack.dart';
import 'sentence_player.dart';

/// The embedded player is available on Android and web, not on Windows.
bool get youtubeSupported => kIsWeb || defaultTargetPlatform == TargetPlatform.android;

/// Plays a YouTube learning pack through the official embedded player
/// (no downloads). Position is polled because the iframe API has no
/// fine-grained position events.
class YouTubeSentencePlayer extends SentencePlayer {
  YouTubeSentencePlayer(this.pack)
      : controller = YoutubePlayerController.fromVideoId(
          videoId: pack.videoId,
          startSeconds: pack.sentences.first.start.inMilliseconds / 1000,
          // Our dock is the only control surface: hide YouTube's own controls,
          // captions and annotations to keep the screen calm.
          params: const YoutubePlayerParams(
            showControls: false,
            enableCaption: false,
            showVideoAnnotations: false,
            showFullscreenButton: false,
            strictRelatedVideos: true,
            playsInline: true,
          ),
        ),
        super(pack.sentences) {
    _timer = Timer.periodic(const Duration(milliseconds: 150), (_) => _poll());
    _sub = controller.stream.listen(_onValue);
  }

  final YouTubePack pack;
  final YoutubePlayerController controller;
  late final Timer _timer;
  late final StreamSubscription<YoutubePlayerValue> _sub;
  bool _busy = false;
  bool _enginePlaying = false;

  /// Why the video can't be played, or null when it's fine.
  String? errorMessage;

  /// Video title from YouTube once the player has loaded it.
  String videoTitle = '';

  @override
  List<double> get speeds => const [0.5, 0.75, 1.0, 1.25];

  void _onValue(YoutubePlayerValue v) {
    final title = v.metaData.title;
    final err = switch (v.error) {
      YoutubeError.none => null,
      YoutubeError.notEmbeddable || YoutubeError.sameAsNotEmbeddable =>
        '이 영상은 제작자가 다른 앱에서의 재생을 막아 두었습니다.',
      YoutubeError.videoNotFound || YoutubeError.cannotFindVideo =>
        '영상을 찾을 수 없습니다. 삭제되었거나 비공개일 수 있어요.',
      _ => '영상을 재생할 수 없습니다. 인터넷 연결을 확인해 주세요.',
    };
    final changed = title != videoTitle || err != errorMessage;
    videoTitle = title;
    errorMessage = err;

    final state = v.playerState;
    _enginePlaying = state == PlayerState.playing || state == PlayerState.buffering;
    if (state == PlayerState.playing || state == PlayerState.paused || state == PlayerState.ended) {
      onEnginePlaying(state == PlayerState.playing);
    }
    if (changed) notifyListeners();
  }

  Future<void> _poll() async {
    if ((!playing && !_enginePlaying) || _busy) return;
    _busy = true;
    try {
      final t = await controller.currentTime;
      onPosition(Duration(milliseconds: (t * 1000).round()));
    } catch (_) {
      // player not ready yet
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> engineSeek(Duration to) =>
      controller.seekTo(seconds: to.inMilliseconds / 1000, allowSeekAhead: true);

  @override
  Future<void> enginePlay() => controller.playVideo();

  @override
  Future<void> enginePause() => controller.pauseVideo();

  @override
  Future<void> engineSpeed(double s) => controller.setPlaybackRate(s);

  @override
  void dispose() {
    _timer.cancel();
    _sub.cancel();
    controller.close();
    super.dispose();
  }
}
