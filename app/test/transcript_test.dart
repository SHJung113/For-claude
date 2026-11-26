import 'package:flutter_test/flutter_test.dart';
import 'package:listenup/youtube/transcript.dart';

void main() {
  test('video ids from common link forms', () {
    expect(videoIdFromUrl('https://youtu.be/h_KUklZdq5w?si=abc'), 'h_KUklZdq5w');
    expect(videoIdFromUrl('https://www.youtube.com/watch?v=M380ySm1vOk&t=3'), 'M380ySm1vOk');
    expect(videoIdFromUrl('https://youtube.com/shorts/J1f47XwvQYA'), 'J1f47XwvQYA');
    expect(videoIdFromUrl('not a link'), isNull);
  });

  test('Korean-UI transcript with chapters becomes one pack per chapter', () {
    const t = '''챕터 1: Ordering pizza
0:000초[Music]
0:1414초luigi's pizza how can i help you
0:1818초hello i'd like to order two pizzas please
챕터 2: Dining at a cafe
1:491분 49초i've been dying to try this place
''';
    final packs = packsFromTranscript(videoId: 'h_KUklZdq5w', transcript: t, title: 'Easy English');
    expect(packs.length, 2);
    expect(packs[0]['chapter'], 'Ordering pizza');
    final s = packs[0]['sentences'] as List;
    expect(s.length, 2); // [Music] dropped
    expect(s[0]['text'], "Luigi's pizza how can I help you");
    expect(s[0]['start_ms'], 13800);
    expect((packs[1]['sentences'] as List).first['text'], "I've been dying to try this place");
  });

  test('English-UI transcript (timestamp on its own line)', () {
    final packs = packsFromTranscript(videoId: 'x' * 11, transcript: '0:05\nhello there\n0:09\nhi');
    expect((packs.single['sentences'] as List).length, 2);
  });

  test('text without timestamps is rejected', () {
    expect(() => packsFromTranscript(videoId: 'x' * 11, transcript: 'just words'),
        throwsA(isA<FormatException>()));
  });
}
