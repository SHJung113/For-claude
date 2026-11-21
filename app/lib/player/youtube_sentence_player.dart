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
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: false,
            strictRelatedVideos: true,
            playsInline: true,
          ),
        ),
        super(pack.sentences) {
    _timer = Timer.periodic(const Duration(milliseconds: 150), (_) => _poll());
  }

  final YouTubePack pack;
  final YoutubePlayerController controller;
  late final Timer _timer;
  bool _busy = false;

  @override
  List<double> get speeds => const [0.5, 0.75, 1.0, 1.25];

  Future<void> _poll() async {
    if (!playing || _busy) return;
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
    controller.close();
    super.dispose();
  }
}
