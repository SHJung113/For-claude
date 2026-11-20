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
.venv/bin/python make_content.py scripts/L01_daily_max_says_hello.yaml ../../app/assets/content/L01-D-001 --model-dir .
```
모델 파일(약 350MB)은 커밋하지 않는다.
