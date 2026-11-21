import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../youtube/pack.dart';
import '../youtube/transcript.dart';

/// Quick add: paste a YouTube link and the copied transcript; the app splits
/// it into chapter packs on the spot. Returns the number of packs saved.
class YouTubeAddPage extends StatefulWidget {
  const YouTubeAddPage({super.key});

  @override
  State<YouTubeAddPage> createState() => _YouTubeAddPageState();
}

class _YouTubeAddPageState extends State<YouTubeAddPage> {
  final _url = TextEditingController();
  final _title = TextEditingController();
  final _text = TextEditingController();
  String? _error;

  Future<void> _paste(TextEditingController c) async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) setState(() => c.text = d!.text!.trim());
  }

  Future<void> _save() async {
    final id = videoIdFromUrl(_url.text);
    if (id == null) {
      setState(() => _error = 'YouTube 링크를 확인해 주세요.');
      return;
    }
    try {
      final packs = packsFromTranscript(videoId: id, transcript: _text.text, title: _title.text);
      final n = await PackStore.saveAll(packs);
      if (mounted) Navigator.of(context).pop(n);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    InputDecoration deco(String label, TextEditingController c, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: '붙여넣기',
            icon: const Icon(Icons.content_paste_rounded),
            onPressed: () => _paste(c),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('YouTube 추가')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        TextField(controller: _url, decoration: deco('영상 링크', _url, hint: 'https://youtu.be/...')),
        const SizedBox(height: 12),
        TextField(controller: _title, decoration: deco('제목 (선택)', _title)),
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          minLines: 8,
          maxLines: 14,
          decoration: deco('자막 (스크립트 표시 내용 전체)', _text,
              hint: '0:14 luigi\'s pizza how can i help you\n0:18 hello i\'d like to order ...'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: cs.error)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _save,
          icon: const Icon(Icons.check_rounded),
          label: const Text('학습 팩 만들기'),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              '자막 복사 방법 (PC 브라우저가 편해요)\n'
              '1. YouTube 영상 아래 "...더보기" → "스크립트 표시"\n'
              '2. 스크립트 전체를 드래그해 복사\n'
              '3. 위 자막 칸에 붙여넣기\n\n'
              '챕터가 있으면 챕터마다 학습 팩이 따로 만들어집니다. '
              '자동 자막이라 문장 부호와 해석은 없습니다. 해석이 필요하면 Claude에게 자막을 보내 '
              '"학습 팩 파일"을 받아 가져오세요.',
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
            ),
          ),
        ),
      ]),
    );
  }
}
