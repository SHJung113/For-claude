import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A sentence the learner starred.
class SavedSentence {
  SavedSentence({
    required this.key,
    required this.idx,
    required this.text,
    this.ko,
    required this.source,
    required this.savedAt,
  });

  factory SavedSentence.fromJson(Map<String, dynamic> j) => SavedSentence(
        key: j['key'] as String,
        idx: j['idx'] as int,
        text: j['text'] as String,
        ko: j['ko'] as String?,
        source: j['source'] as String,
        savedAt: DateTime.parse(j['savedAt'] as String),
      );

  /// Content key: `tts:CONTENT_ID` or `yt:PACK_FILE_NAME`.
  final String key;
  final int idx;
  final String text;
  final String? ko;

  /// Title of the content it came from.
  final String source;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'key': key,
        'idx': idx,
        'text': text,
        'ko': ko,
        'source': source,
        'savedAt': savedAt.toIso8601String(),
      };
}

/// Everything the app remembers about the learner, on this device only:
/// playback settings, per-content progress, study time and saved sentences.
class StudyStore extends ChangeNotifier {
  StudyStore._();
  static final StudyStore instance = StudyStore._();

  late SharedPreferences _p;

  static const _kRepeat = 'set.repeat';
  static const _kGap = 'set.gap';
  static const _kProgress = 'progress';
  static const _kLast = 'last';
  static const _kDaily = 'daily';
  static const _kSaved = 'saved';

  Map<String, dynamic> _progress = {};
  Map<String, dynamic> _daily = {};
  List<SavedSentence> _saved = [];

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    _progress = _readMap(_kProgress);
    _daily = _readMap(_kDaily);
    try {
      _saved = [
        for (final e in jsonDecode(_p.getString(_kSaved) ?? '[]') as List)
          SavedSentence.fromJson(e as Map<String, dynamic>)
      ];
    } catch (_) {
      _saved = [];
    }
  }

  Map<String, dynamic> _readMap(String k) {
    try {
      return jsonDecode(_p.getString(k) ?? '{}') as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // ---------------- playback settings ----------------

  /// How many times each sentence plays during continuous playback.
  int get repeatCount => _p.getInt(_kRepeat) ?? 1;

  /// Pause after each sentence in seconds; -1 = as long as the sentence
  /// itself (time to shadow it).
  int get gapSeconds => _p.getInt(_kGap) ?? 0;

  Future<void> setPlayback({int? repeat, int? gap}) async {
    if (repeat != null) await _p.setInt(_kRepeat, repeat);
    if (gap != null) await _p.setInt(_kGap, gap);
    notifyListeners();
  }

  // ---------------- progress ----------------

  Map<String, dynamic> _entry(String key) =>
      (_progress[key] as Map<String, dynamic>?) ?? <String, dynamic>{};

  /// Sentence to resume from.
  int lastIndex(String key) => (_entry(key)['i'] as int?) ?? 0;

  /// Furthest sentence reached (for the progress bar).
  int maxIndex(String key) => (_entry(key)['m'] as int?) ?? -1;

  bool isDone(String key) => (_entry(key)['d'] as bool?) ?? false;

  Future<void> saveProgress(String key, {required int index, required int total, String? title}) async {
    final e = _entry(key);
    e['i'] = index;
    e['m'] = index > ((e['m'] as int?) ?? -1) ? index : e['m'];
    if (index >= total - 1) e['d'] = true;
    _progress[key] = e;
    await _p.setString(_kProgress, jsonEncode(_progress));
    if (title != null) await _p.setString(_kLast, jsonEncode({'key': key, 'title': title}));
    notifyListeners();
  }

  /// The content opened most recently: {key, title}, or null.
  Map<String, dynamic>? get last {
    try {
      final s = _p.getString(_kLast);
      return s == null ? null : jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ---------------- study time ----------------

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> addStudySeconds(int s) async {
    if (s <= 0) return;
    final k = _day(DateTime.now());
    _daily[k] = ((_daily[k] as int?) ?? 0) + s;
    await _p.setString(_kDaily, jsonEncode(_daily));
    notifyListeners();
  }

  int get todayMinutes => (((_daily[_day(DateTime.now())] as int?) ?? 0) / 60).floor();

  /// Days in a row with at least one minute of listening, ending today
  /// (or yesterday, so the streak doesn't look broken before today's session).
  int get streakDays {
    bool studied(DateTime d) => ((_daily[_day(d)] as int?) ?? 0) >= 60;
    var d = DateTime.now();
    if (!studied(d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (studied(d)) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  // ---------------- saved sentences ----------------

  List<SavedSentence> get saved => List.unmodifiable(_saved.reversed);

  bool isSaved(String key, int idx) => _saved.any((s) => s.key == key && s.idx == idx);

  Future<void> toggleSaved(SavedSentence s) async {
    final before = _saved.length;
    _saved.removeWhere((e) => e.key == s.key && e.idx == s.idx);
    if (_saved.length == before) _saved.add(s);
    await _p.setString(_kSaved, jsonEncode([for (final e in _saved) e.toJson()]));
    notifyListeners();
  }
}

final study = StudyStore.instance;
