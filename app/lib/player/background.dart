import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'sentence_player.dart';

/// Background playback for TTS content (Android): keeps playing with the
/// screen off and shows previous / play-pause / next / repeat controls in the
/// notification, on the lock screen and for headset buttons.
///
/// YouTube is never attached: its terms require the embedded player to be
/// visible while playing.
class ListenUpAudioHandler extends BaseAudioHandler {
  SentencePlayer? _p;

  static ListenUpAudioHandler? instance;

  /// Why the service could not start (shown on the check screen), or null.
  static String? initError;

  /// The playback service exists on this platform (Android).
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Starts the audio service. Android only; elsewhere playback simply
  /// stays in the foreground.
  static Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      instance = await AudioService.init(
        builder: ListenUpAudioHandler.new,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.listenup.listenup.playback',
          androidNotificationChannelName: 'ListenUp 재생',
          androidNotificationIcon: 'drawable/ic_launcher_monochrome',
          // Stay in the foreground while paused: the pause between sentences
          // (repeat settings) must not let Android stop the service.
          androidStopForegroundOnPause: false,
        ),
      );
    } catch (e) {
      initError = '$e';
      debugPrint('audio_service unavailable: $e');
    }
  }

  /// Android 13+ needs permission to show the media notification
  /// (and with it the lock-screen controls). Asked once, on first use.
  static Future<void> askNotificationPermission() async {
    if (instance == null) return;
    try {
      if (await Permission.notification.isDenied) await Permission.notification.request();
    } catch (_) {}
  }

  /// Whether a player is attached and playing right now (for the check screen).
  bool get isPlaying => _p?.playing ?? false;

  void attach(SentencePlayer p, {required String title, required String subtitle}) {
    _p?.removeListener(_sync);
    _p = p;
    p.addListener(_sync);
    mediaItem.add(MediaItem(id: title, title: title, artist: subtitle, album: 'ListenUp'));
    _sync();
  }

  void detach(SentencePlayer p) {
    if (_p != p) return;
    p.removeListener(_sync);
    _p = null;
    playbackState.add(PlaybackState(processingState: AudioProcessingState.idle, playing: false));
  }

  void _sync() {
    final p = _p;
    if (p == null) return;
    final item = mediaItem.value;
    final line = '문장 ${p.index + 1} / ${p.sentences.length}';
    if (item != null && item.displaySubtitle != line) {
      mediaItem.add(item.copyWith(displaySubtitle: line));
    }
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        p.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.rewind, // "this sentence again"
      ],
      systemActions: const {MediaAction.skipToNext, MediaAction.skipToPrevious, MediaAction.rewind},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.ready,
      playing: p.playing,
    ));
  }

  @override
  Future<void> play() async {
    final p = _p;
    if (p != null && !p.playing) await p.toggle();
  }

  @override
  Future<void> pause() async {
    final p = _p;
    if (p != null && p.playing) await p.toggle();
  }

  @override
  Future<void> skipToNext() async => _p?.next();

  @override
  Future<void> skipToPrevious() async => _p?.prev();

  @override
  Future<void> rewind() async => _p?.repeat();

  @override
  Future<void> stop() async {
    await pause();
    await super.stop();
  }
}
