import 'dart:convert';

import 'package:flutter/services.dart';

class Sentence {
  Sentence.fromJson(Map<String, dynamic> j)
      : idx = j['idx'] as int,
        speaker = j['speaker'] as String,
        text = j['text'] as String,
        ko = j['ko'] as String?,
        start = Duration(milliseconds: j['start_ms'] as int),
        end = Duration(milliseconds: j['end_ms'] as int);

  final int idx;
  final String speaker;
  final String text;
  final String? ko; // Korean translation
  final Duration start;
  final Duration end;
}

class Content {
  Content.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        level = j['level'] as int,
        track = j['track'] as String,
        title = j['title'] as String,
        duration = Duration(milliseconds: j['duration_ms'] as int),
        sentences = [
          for (final s in j['sentences'] as List) Sentence.fromJson(s as Map<String, dynamic>)
        ];

  final String id;
  final int level;
  final String track;
  final String title;
  final Duration duration;
  final List<Sentence> sentences;

  String get audioAsset => 'content/$id.mp3';
}

/// Loads every bundled content.json listed in the asset manifest.
Future<List<Content>> loadCatalog() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final paths = manifest
      .listAssets()
      .where((p) => p.startsWith('assets/content/') && p.endsWith('.json'))
      .toList()
    ..sort();
  return [
    for (final p in paths)
      Content.fromJson(jsonDecode(await rootBundle.loadString(p)) as Map<String, dynamic>)
  ];
}
