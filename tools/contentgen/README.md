# contentgen

대본(YAML)을 앱 콘텐츠 번들(`audio.mp3` + `content.json`)로 만드는 도구.

- TTS: [Kokoro](https://github.com/thewh1teagle/kokoro-onnx) (오픈소스, 무료, CPU 실행)
- 문장마다 따로 합성하므로 문장 타임스탬프가 정확함
- 단계 목표 속도(wpm)에 맞을 때까지 말하기 속도를 자동 조정
- `ffmpeg` 필요

```bash
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
curl -LO https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx
curl -LO https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin
.venv/bin/python make_content.py levels/*.yaml --out ../../app/assets/content --model-dir .
```
모델 파일(약 350MB)은 커밋하지 않는다.

- `levels/Lxx.yaml`: 단계별 대본 묶음 (`contents:` 목록)
- `characters.yaml`: 등장인물별 기본 목소리
- 이미 만든 번들은 건너뛴다 (`--force`로 다시 생성)
- `translations/ko.yaml`: 문장별 한국어 해석. 콘텐츠 생성 후 `python apply_translations.py --content ../../app/assets/content` 로 반영 (문장 수가 다르면 실패)
