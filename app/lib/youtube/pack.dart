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

  /// One pack per video chapter: a pack made by Claude replaces the
  /// auto-made pack of the same chapter.
  String get fileName {
    final part = (chapter.isNotEmpty ? chapter : title).toLowerCase();
    return '${videoId}_${part.replaceAll(RegExp(r'[^a-z0-9]+'), '_')}.json';
  }

  /// Text to paste into the Claude chat to get a translated pack:
  /// link, chapter headings and timestamped caption lines.
  static String requestText(List<YouTubePack> packs) {
    final b = StringBuffer('ListenUp 해석 요청\nhttps://youtu.be/${packs.first.videoId}\n');
    var n = 1;
    for (final p in packs) {
      if (p.chapter.isNotEmpty) b.writeln('챕터 ${n++}: ${p.chapter}');
      for (final s in p.sentences) {
        final t = (s.start.inMilliseconds + 200) ~/ 1000;
        b.writeln('${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')} ${s.text}');
      }
    }
    return b.toString();
  }
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
    // Keyed by chapter; if old entries collide, prefer the translated one.
    final byKey = <String, YouTubePack>{};
    for (final v in (await _all()).values) {
      try {
        final p = YouTubePack.fromJson(jsonDecode(v) as Map<String, dynamic>);
        final old = byKey[p.fileName];
        if (old == null || (!old.hasTranslation && p.hasTranslation)) byKey[p.fileName] = p;
      } catch (_) {
        // skip broken entries
      }
    }
    final packs = byKey.values.toList()
      ..sort((a, b) => a.videoId == b.videoId
          ? a.sentences.first.start.compareTo(b.sentences.first.start)
          : a.videoId.compareTo(b.videoId));
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
      // Drop any stored entry for the same chapter (older key formats too).
      all.removeWhere((_, v) {
        try {
          return YouTubePack.fromJson(jsonDecode(v) as Map<String, dynamic>).fileName == pack.fileName;
        } catch (_) {
          return false;
        }
      });
      all[pack.fileName] = jsonEncode(j);
    }
    await _write(all);
    return packs.length;
  }

  static Future<void> delete(YouTubePack pack) async {
    final all = await _all();
    all.removeWhere((_, v) {
      try {
        return YouTubePack.fromJson(jsonDecode(v) as Map<String, dynamic>).fileName == pack.fileName;
      } catch (_) {
        return false;
      }
    });
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
