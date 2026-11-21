---
name: youtube-pack
description: Turn YouTube transcripts the user pastes (the app's "ListenUp 해석 요청" copy, or text from YouTube's "스크립트 표시" panel) into translated ListenUp learning packs — cleaned sentences, speakers, Korean translation, key expressions — delivered as one bundle file to import in the app. Use whenever the user pastes such a transcript or asks for 해석/학습 팩 for a YouTube video.
---

# YouTube 학습 팩 만들기

사용자가 붙여넣은 자막을 앱에서 가져올 수 있는 **학습 팩 번들(JSON)** 로 만든다. 한 번에 여러 영상을 받으면 전부 **파일 하나**로 묶는다.

## 0. 절대 규칙
- 자막·학습 팩은 저작물이다. **git에 커밋하지 않는다.** 작업은 `youtube-local/`(gitignore됨) 또는 스크래치패드에서만 한다.
- 결과물은 `SendUserFile`로 전달한다(`display: attach`).
- 이 환경에서는 YouTube 접속이 막혀 있다. 영상 내용은 받은 자막만 근거로 하고, 추측으로 채우지 않는다.

## 1. 입력 저장
붙여넣은 텍스트를 영상마다 파일로 저장한다: `youtube-local/<slug>/request.txt`
- 입력 형식 두 가지 모두 지원:
  - 앱 복사본: `ListenUp 해석 요청` / `https://youtu.be/<id>` / `챕터 N: 이름` / `m:ss 텍스트`
  - YouTube 스크립트 패널(한국어 UI): `0:1414초텍스트`, `챕터 1: 이름`, `[Music]`
- 링크가 없으면 사용자에게 영상 링크를 묻는다(앱에서 재생하려면 필수).

## 2. 뼈대 만들기
```bash
python3 tools/youtube/new_spec.py youtube-local/<slug>/request.txt --out-dir youtube-local/<slug>
```
`spec.yaml`에 챕터별로 자막 줄이 `["?", "<자막>", ""]` 형태로 들어 있고, 챕터마다 대략 wpm/레벨 주석이 붙는다.

## 3. spec.yaml 다듬기 (핵심 작업)
챕터마다 `sentences`를 **완전히 다시 쓴다**. 형식: `[화자, "영어 문장", "한국어 해석"]`
1. **문장 단위로 나누기**: 자막 한 줄에 여러 문장·여러 화자가 섞여 있다. 한 항목 = 한 화자의 한 문장(짧은 응답 "Yes." "Okay."도 따로).
2. **문장 부호·대소문자** 복원. 고유명사 대문자(Max, New York, Cobb salad).
3. **자동 자막 오류 수정**: 문맥으로 확실한 것만(예: carb salad→Cobb salad, sure bob→short bob, tuner/stake→tuna/steak, first ride→first right, I'm like→I'd like). 고친 것은 `notes`에 기록.
4. **단어는 최대한 자막 그대로 유지** — 시간 정렬이 자막 단어 순서에 의존한다. 군더더기("uh")는 빼도 되지만, 말을 바꾸어 쓰거나 순서를 바꾸지 않는다. 숫자는 자막 표기를 따른다(자막이 "forty nine"이면 "forty-nine").
5. **화자**: 이름이 나오면 이름, 아니면 역할(Staff/Customer/Barber/Librarian), 그것도 모르면 A/B. 추정한 경우 `notes`에 "화자 구분은 문맥으로 추정".
6. **한국어 해석**: 자연스러운 구어체, 상황에 맞는 존댓말/반말(점원↔손님은 존댓말, 친구끼리는 반말). 직역보다 뜻 전달. 단위·화폐는 한국어로(six inches→15센티미터 정도, 15→15달러).
7. **expressions** 4~7개: `["영어 표현", "뜻", "짧은 메모"]`. 그 장면에서 실제로 쓸 만한 덩어리 표현(주문·요청·인사·관용구). 미국/영국 차이가 나오면 메모에 적는다.
8. `title`은 챕터명을 Title Case로(TODO 금지).

## 4. 빌드
```bash
python3 tools/youtube/make_pack.py youtube-local/<slug>/spec.yaml [다른 영상 spec ...] \
  --out youtube-local/listenup-<이름>.json
```
- 미완성 항목(`?` 화자, 빈 해석, TODO 제목)이 있으면 실패한다 → 고치고 다시.
- 각 챕터의 **정렬률이 95% 이상**인지 확인. 낮으면 3-4번(단어를 자막과 다르게 바꿨는지)을 점검.
- 팩이 2개 이상이면 자동으로 번들(`listenup-youtube-bundle`)이 된다.

## 5. 전달
`SendUserFile`로 번들을 보내고 짧게 안내한다:
- 장면별 표(제목 · 문장 수 · wpm/≈레벨)
- 가져오기: YouTube 탭 → **학습 팩 파일 가져오기** → 파일 선택. 같은 영상·챕터의 자동 팩은 덮어쓴다.
- 고친 자막 오류와 화자 추정 여부를 한두 줄로.

## 참고
- 팩 형식·키 규칙: `app/lib/youtube/pack.dart` (videoId + chapter로 식별)
- 단계 속도 기준: `docs/CURRICULUM.md` §2
- 문장 시간은 자막 줄 안에서 단어를 균등 배분해 추정한다(±0.5초). 앞뒤 여유는 make_pack.py의 PAD 값.
