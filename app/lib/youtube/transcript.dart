/// Turns a YouTube link + the text copied from YouTube's "Show transcript"
/// panel into learning packs, right on the phone (port of
/// tools/youtube/parse_transcript.py).
///
/// Copied text looks like (Korean UI):
///   챕터 1: Ordering pizza
///   0:1414초luigi's pizza how can i help you
///   1:001분yes that's right
/// English UI copies look like "0:14\nluigi's pizza ..." — both work.
library;

final _lineRe = RegExp(r'^((?:\d+:)?\d{1,2}:\d{2})(?:\d+시간\s?)?(?:\d+분\s?)?(?:\d+초)?(.*)$');
final _tsOnlyRe = RegExp(r'^((?:\d+:)?\d{1,2}:\d{2})$');
final _chapterRe = RegExp(r'^(?:챕터|Chapter)\s*\d+\s*[:：]\s*(.+)$', caseSensitive: false);
final _noiseRe = RegExp(r'^\[(?:music|applause|laughter|음악|박수)\]$', caseSensitive: false);
final _wordRe = RegExp(r"[A-Za-z0-9']+");

/// Extracts the 11-character video id from common YouTube link forms.
String? videoIdFromUrl(String url) {
  final u = url.trim();
  final patterns = [
    RegExp(r'youtu\.be/([A-Za-z0-9_-]{11})'),
    RegExp(r'[?&]v=([A-Za-z0-9_-]{11})'),
    RegExp(r'youtube\.com/(?:shorts|embed|live)/([A-Za-z0-9_-]{11})'),
    RegExp(r'^([A-Za-z0-9_-]{11})$'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(u);
    if (m != null) return m.group(1);
  }
  return null;
}

int _seconds(String ts) => ts.split(':').fold(0, (a, b) => a * 60 + int.parse(b));

/// Light clean-up of auto captions: capital first letter, "i" → "I".
String _tidy(String s) {
  var t = s.replaceAllMapped(RegExp(r"\bi\b(?=$|[\s'])"), (_) => 'I');
  if (t.isNotEmpty) t = t[0].toUpperCase() + t.substring(1);
  return t;
}

class _Line {
  _Line(this.start, this.text, this.chapter);
  final int start;
  final String text;
  final String? chapter;
}

/// Builds one pack JSON (same format as make_pack.py) per chapter.
/// Each caption line becomes one "sentence". Throws [FormatException]
/// when nothing usable is found.
List<Map<String, dynamic>> packsFromTranscript({
  required String videoId,
  required String transcript,
  String title = '',
}) {
  final lines = <_Line>[];
  String? chapter;
  int? pendingTs; // English UI puts the timestamp on its own line
  for (final raw in transcript.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final ch = _chapterRe.firstMatch(line);
    if (ch != null) {
      chapter = ch.group(1)!.trim();
      continue;
    }
    if (_tsOnlyRe.hasMatch(line)) {
      pendingTs = _seconds(line);
      continue;
    }
    final m = _lineRe.firstMatch(line);
    if (m != null) {
      lines.add(_Line(_seconds(m.group(1)!), m.group(2)!.trim(), chapter));
      pendingTs = null;
    } else if (pendingTs != null) {
      lines.add(_Line(pendingTs, line, chapter));
      pendingTs = null;
    }
  }
  if (lines.isEmpty) {
    throw const FormatException('자막에서 시간 정보를 찾지 못했습니다. "스크립트 표시"의 내용을 그대로 붙여넣어 주세요.');
  }

  // Group by chapter, keep only speech lines; each ends where the next line starts.
  final groups = <String?, List<Map<String, dynamic>>>{};
  final order = <String?>[];
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (l.text.isEmpty || _noiseRe.hasMatch(l.text)) continue;
    final next = i + 1 < lines.length ? lines[i + 1].start : l.start + 5;
    final end = next - l.start > 12 ? l.start + 12 : next;
    if (!groups.containsKey(l.chapter)) order.add(l.chapter);
    final g = groups.putIfAbsent(l.chapter, () => []);
    g.add({
      'idx': g.length,
      'speaker': '',
      'text': _tidy(l.text),
      'start_ms': (l.start * 1000 - 200).clamp(0, 1 << 31),
      'end_ms': end * 1000 + 300,
    });
  }
  if (groups.isEmpty) throw const FormatException('대사가 있는 자막 줄이 없습니다.');

  final base = title.trim().isEmpty ? 'YouTube $videoId' : title.trim();
  return [
    for (final ch in order)
      () {
        final s = groups[ch]!;
        final words = s.fold<int>(0, (a, e) => a + _wordRe.allMatches(e['text'] as String).length);
        final secs = s.fold<int>(0, (a, e) => a + ((e['end_ms'] as int) - (e['start_ms'] as int))) / 1000;
        return <String, dynamic>{
          'type': 'listenup-youtube-pack',
          'version': 1,
          'videoId': videoId,
          'title': ch == null ? base : (order.length > 1 ? ch : '$base · $ch'),
          'channel': title.trim().isEmpty ? 'YouTube' : base,
          'chapter': ch ?? '',
          'wpm': secs > 0 ? (words / (secs / 60)).round() : 0,
          'sentences': s,
          'expressions': <Map<String, dynamic>>[],
          'notes': ['앱에서 자동 생성 (자동 자막 기준, 해석 없음)'],
        };
      }(),
  ];
}
