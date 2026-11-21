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

  bool get hasTranslation => sentences.any((s) => s.ko != null);

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

  static Future<void> _write(Map<String, String> all) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
  }

  /// Saves pack JSON objects; returns how many were saved.
  static Future<int> saveAll(List<Map<String, dynamic>> packs) async {
    final all = await _all();
    for (final j in packs) {
      final pack = YouTubePack.fromJson(j); // validates the shape
      all[pack.fileName] = jsonEncode(j);
    }
    await _write(all);
    return packs.length;
  }

  static Future<void> delete(YouTubePack pack) async {
    final all = await _all()..remove(pack.fileName);
    await _write(all);
  }

  /// Lets the user pick a pack file (one pack, or a bundle of many) and
  /// saves it. Returns the number of packs saved (0 if cancelled).
  static Future<int> importFromPicker() async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) return 0;
    final json = jsonDecode(utf8.decode(await files.first.readAsBytes()));
    if (json is Map<String, dynamic> && json['type'] == 'listenup-youtube-pack') {
      return saveAll([json]);
    }
    if (json is Map<String, dynamic> && json['type'] == 'listenup-youtube-bundle') {
      return saveAll([for (final p in json['packs'] as List) p as Map<String, dynamic>]);
    }
    throw const FormatException('ListenUp 학습 팩 파일이 아닙니다.');
  }
}
