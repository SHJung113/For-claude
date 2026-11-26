import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:listenup/data/content.dart';
import 'package:listenup/player/sentence_player.dart';

/// Engine stand-in that records commands; tests feed positions by hand.
class FakePlayer extends SentencePlayer {
  FakePlayer(super.sentences);
  final log = <String>[];

  @override
  List<double> get speeds => const [0.75, 1.0];
  @override
  Future<void> engineSeek(Duration to) async => log.add('seek ${to.inMilliseconds}');
  @override
  Future<void> enginePlay() async => log.add('play');
  @override
  Future<void> enginePause() async => log.add('pause');
  @override
  Future<void> engineSpeed(double s) async {}
}

List<Sentence> three() => [
      for (var i = 0; i < 3; i++)
        Sentence.fromJson({
          'idx': i,
          'speaker': 'A',
          'text': 's$i',
          'start_ms': i * 2000,
          'end_ms': i * 2000 + 1500,
        })
    ];

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('single sentence stops at its end', () async {
    final p = FakePlayer(three());
    await p.playSentence(1);
    expect(p.log, ['seek 2000', 'play']);
    p.onPosition(ms(2500));
    expect(p.playing, isTrue);
    p.onPosition(ms(3600));
    expect(p.playing, isFalse);
    expect(p.log.last, 'pause');
  });

  test('stale position before a seek lands is ignored', () async {
    final p = FakePlayer(three());
    await p.playSentence(0);
    p.onPosition(ms(5200)); // old position from a previous sentence
    expect(p.playing, isTrue);
  });

  test('next on the last sentence does not replay it', () async {
    final p = FakePlayer(three());
    await p.playSentence(2);
    p.log.clear();
    p.next();
    expect(p.log, isEmpty);
  });

  test('flowing mode follows position and finishes', () async {
    final p = FakePlayer(three());
    await p.toggle();
    p.onPosition(ms(2100));
    expect(p.index, 1);
    p.onPosition(ms(5600));
    expect(p.finished, isTrue);
    expect(p.playing, isFalse);
    await p.toggle(); // after finishing, play restarts from the top
    expect(p.index, 0);
  });

  test('stepped mode repeats each sentence and pauses between', () {
    fakeAsync((async) {
      final p = FakePlayer(three())..setRepeat(count: 2, gapSeconds: 1);
      p.toggle();
      async.flushMicrotasks();
      p.onPosition(ms(1600)); // end of sentence 0, first play
      expect(p.waiting, isTrue);
      expect(p.index, 0);
      async.elapse(const Duration(seconds: 1));
      expect(p.waiting, isFalse);
      expect(p.repeatNo, 2);
      expect(p.index, 0);
      p.onPosition(ms(1600)); // end of second play
      async.elapse(const Duration(seconds: 1));
      expect(p.index, 1);
      expect(p.repeatNo, 1);
      expect(p.playing, isTrue);
    });
  });

  test('pause during the gap stops the sequence', () {
    fakeAsync((async) {
      final p = FakePlayer(three())..setRepeat(count: 1, gapSeconds: 2);
      p.toggle();
      async.flushMicrotasks();
      p.onPosition(ms(1600));
      expect(p.waiting, isTrue);
      p.toggle(); // pause
      async.elapse(const Duration(seconds: 3));
      expect(p.playing, isFalse);
      expect(p.index, 0);
    });
  });

  test('"sentence length" gap waits as long as the sentence', () {
    fakeAsync((async) {
      final p = FakePlayer(three())..setRepeat(count: 1, gapSeconds: -1);
      p.toggle();
      async.flushMicrotasks();
      p.onPosition(ms(1600));
      async.elapse(const Duration(milliseconds: 1400));
      expect(p.waiting, isTrue);
      async.elapse(const Duration(milliseconds: 200));
      expect(p.waiting, isFalse);
      expect(p.index, 1);
    });
  });

  test('stepped mode finishes after the last sentence', () {
    fakeAsync((async) {
      final p = FakePlayer(three())..setRepeat(count: 1, gapSeconds: 1);
      p.index = 2;
      p.toggle();
      async.flushMicrotasks();
      p.onPosition(ms(5600));
      async.elapse(const Duration(seconds: 1));
      expect(p.playing, isFalse);
      expect(p.finished, isTrue);
    });
  });

  test('positions while paused do not move the resume position', () {
    final p = FakePlayer(three());
    p.index = 2; // resumed here
    p.onPosition(Duration.zero); // engine reports 0 after loading
    expect(p.index, 2);
  });

  test('a tap on the video (engine started outside the app) syncs state', () {
    final p = FakePlayer(three());
    p.onEnginePlaying(true);
    expect(p.playing, isTrue);
    p.onEnginePlaying(false);
    expect(p.playing, isFalse);
  });
}
