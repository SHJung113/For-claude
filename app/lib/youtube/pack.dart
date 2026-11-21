import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/content.dart';

/// A YouTube learning pack made by tools/youtube/make_pack.py.
/// Packs hold transcript text, so they are stored only on this device.
class YouTubePack {
  YouTubePack.fromJson(Map<String, dynamic> j)
      : videoId = j['videoId'] as String,
        title = j['title'] as String,
        channel = (j['channel'] as String?) ?? '',
        chapter = (j['chapter'] as String?) ?? '',
        wpm = (j['wpm'] as num?)?.round() ?? 0,
        sentences = [
          for (final s in j['sentences'] as List) Sentence.fromJson(s as Map<String, dynamic>)
        ],
        expressions = [
          for (final e in (j['expressions'] as List?) ?? const [])
            Expression(e['en'] as String, e['ko'] as String, (e['note'] as String?) ?? '')
        ];

  final String videoId;
  final String title;
  final String channel;
  final String chapter;
  final int wpm;
  final List<Sentence> sentences;
  final List<Expression> expressions;

  /// Closest curriculum level by speech rate (see docs/CURRICULUM.md).
  int get estimatedLevel {
    const targets = [75, 85, 95, 100, 105, 110, 120, 125, 130, 135,
                     140, 145, 150, 155, 160, 165, 170, 175, 185, 195];
    var best = 0;
    for (var i = 1; i < targets.length; i++) {
      if ((targets[i] - wpm).abs() < (targets[best] - wpm).abs()) best = i;
    }
    return best + 1;
  }

  String get fileName => '${videoId}_${title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.json';
}

class Expression {
  const Expression(this.en, this.ko, this.note);
  final String en;
  final String ko;
  final String note;
}

/// Packs are kept in app-private storage on this device only.
class PackStore {
  static const _key = 'youtube_packs';

  static Future<Map<String, String>> _all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
  }

  static Future<List<YouTubePack>> list() async {
    final packs = <YouTubePack>[];
    for (final v in (await _all()).values) {
      try {
        packs.add(YouTubePack.fromJson(jsonDecode(v) as Map<String, dynamic>));
      } catch (_) {
        // skip broken entries
      }
    }
    packs.sort((a, b) => a.title.compareTo(b.title));
    return packs;
  }

  /// Lets the user pick a pack file and saves it. Returns the pack, or null
  /// if cancelled. Throws [FormatException] for files that aren't packs.
  static Future<YouTubePack?> importFromPicker() async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) return null;
    final text = utf8.decode(await files.first.readAsBytes());
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic> || json['type'] != 'listenup-youtube-pack') {
      throw const FormatException('ListenUp 학습 팩 파일이 아닙니다.');
    }
    final pack = YouTubePack.fromJson(json);
    final all = await _all()..[pack.fileName] = text;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
    return pack;
  }
}
