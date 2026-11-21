# ListenUp — 개인용 영어 듣기 훈련 앱

사용자 한 명(한국어 사용자, 영어 듣기 초급)을 위한 개인용 앱. 대화와 문서는 **한국어**로 한다.
사용자 선호: 복잡한 문제는 분해 → 신뢰도와 함께 해결 → 검증 → 종합 순서로 답한다.

## 문서
- `docs/PLAN.md` — 계획서(현재 v0.4), 로드맵 M0.5~M5, 결정 사항
- `docs/CURRICULUM.md` — 20단계(미국 유치원→대학), TTS 콘텐츠 체계
- `docs/DESIGN.md` — UI(Material 3, 하단 탭 + 하단 조작 독)
- `docs/INSTALL.md` — 폰 설치(고정 링크/QR)

## 구조
- `app/` — Flutter 앱 (Android 폰 + Windows PC; 웹은 화면 확인용)
  - `lib/player/` — `SentencePlayer`(문장 단위 재생 공통), TTS·YouTube 구현
  - `lib/ui/` — `home_page.dart`(오늘/레벨/YouTube 탭), `player_page.dart`(학습 화면), `youtube_add_page.dart`
  - `lib/youtube/` — 학습 팩 모델·저장(`pack.dart`), 앱 내 자막 파서(`transcript.dart`)
  - `assets/content/<id>.json|.mp3` — 내장 TTS 콘텐츠
- `tools/contentgen/` — TTS 콘텐츠 생성(Kokoro, 무료): `levels/Lxx.yaml` → `make_content.py` → `apply_translations.py`(`translations/ko.yaml`)
- `tools/youtube/` — YouTube 학습 팩: `parse_transcript.py`, `new_spec.py`, `make_pack.py`

## 반복 작업
- **YouTube 자막 → 해석 학습 팩**: 스킬 `youtube-pack`(`.claude/skills/youtube-pack/SKILL.md`)을 따른다.
- **TTS 콘텐츠 추가**: `tools/contentgen/README.md`. 새 대본을 만들면 `translations/ko.yaml`에 문장별 해석도 추가한다(문장 수가 맞아야 함).

## 규칙
- YouTube 자막·학습 팩은 저작물 → **절대 커밋 금지**(`youtube-local/` 사용). 영상 다운로드 금지(공식 임베드 플레이어만).
- 빌드는 GitHub Actions(`.github/workflows/build.yml`): push하면 APK + Windows zip이 GitHub Release로 배포되고,
  `https://github.com/SHJung113/For-claude/releases/latest/download/listenup.apk`가 항상 최신.
- Android 서명은 GitHub Secret(`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`)의 고정 키. 이 키를 바꾸면 사용자가 앱을 지우고 다시 설치해야 한다.
- 검증 범위를 정직하게 말한다: 이 환경에는 Android 기기가 없고 YouTube가 막혀 있다. 웹 빌드 + Playwright 스크린샷으로 UI를 확인하고, 폰에서만 되는 것(소리, YouTube 재생, 진동)은 "미검증"으로 알린다.
- Flutter SDK는 세션마다 새로 받아야 할 수 있다(`storage.googleapis.com` 접근 가능).
