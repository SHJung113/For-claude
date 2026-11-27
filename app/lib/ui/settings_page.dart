import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../player/background.dart';

/// Build number injected by CI (`--dart-define=BUILD_NO=...`).
const buildNo = String.fromEnvironment('BUILD_NO', defaultValue: 'dev');

/// Settings + a self-check for background playback, so problems on a
/// particular phone can be seen and fixed without logs.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with WidgetsBindingObserver {
  PermissionStatus? _notif;
  PermissionStatus? _battery;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check when coming back from the system settings screens.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (!ListenUpAudioHandler.supported) return;
    try {
      final n = await Permission.notification.status;
      final b = await Permission.ignoreBatteryOptimizations.status;
      if (mounted) {
        setState(() {
          _notif = n;
          _battery = b;
        });
      }
    } catch (_) {}
  }

  Future<void> _ask(Permission p) async {
    final st = await p.request();
    if (st.isPermanentlyDenied) await openAppSettings();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final service = ListenUpAudioHandler.instance != null;
    Widget row(bool ok, String title, String detail, {String? action, VoidCallback? onAction}) => Card(
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            leading: Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: ok ? cs.primary : cs.error, size: 28),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(detail),
            trailing: action == null ? null : FilledButton.tonal(onPressed: onAction, child: Text(action)),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('설정 · 점검')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text('백그라운드 재생 점검',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: cs.primary)),
        ),
        if (!ListenUpAudioHandler.supported)
          row(false, '이 기기에서는 지원하지 않음', 'Android 폰에서만 화면을 끄고 들을 수 있습니다.')
        else ...[
          row(service, '재생 서비스',
              service ? '켜짐 — 화면을 꺼도 재생할 준비가 되어 있어요' : '꺼짐 — ${ListenUpAudioHandler.initError ?? '시작되지 않았습니다'}'),
          const SizedBox(height: 8),
          row(_notif?.isGranted ?? false, '알림 권한',
              _notif == null ? '확인 중…' : (_notif!.isGranted ? '허용됨 — 잠금화면 버튼이 보여요' : '꺼짐 — 잠금화면·알림 버튼이 안 보여요'),
              action: (_notif?.isGranted ?? true) ? null : '허용',
              onAction: () => _ask(Permission.notification)),
          const SizedBox(height: 8),
          row(_battery?.isGranted ?? false, '배터리 최적화 제외',
              _battery == null
                  ? '확인 중…'
                  : (_battery!.isGranted ? '제외됨 — 화면이 꺼져도 멈추지 않아요' : '적용 중 — 화면이 꺼지면 폰이 앱을 멈출 수 있어요'),
              action: (_battery?.isGranted ?? true) ? null : '제외',
              onAction: () => _ask(Permission.ignoreBatteryOptimizations)),
          const SizedBox(height: 12),
          Card(
            color: cs.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '그래도 멈추면 (특히 삼성)\n'
                '• 설정 → 애플리케이션 → ListenUp → 배터리 → "제한 없음"\n'
                '• 설정 → 배터리 → 백그라운드 사용 제한 → "사용하지 않는 앱을 절전 상태로"에서 ListenUp 제외\n\n'
                '재생 중 알림창에 ListenUp 재생 알림이 보이면 백그라운드 재생이 켜진 상태입니다.\n'
                'YouTube는 약관상 화면이 켜져 있을 때만 재생됩니다.',
                style: TextStyle(height: 1.5, color: cs.onSurfaceVariant),
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
          child: Text('앱 정보', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: cs.primary)),
        ),
        Card(
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('버전'),
            subtitle: Text('build-$buildNo'),
          ),
        ),
      ]),
    );
  }
}
