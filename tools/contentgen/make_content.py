"""Build a content bundle (audio.mp3 + content.json) from a script YAML.

Usage: python make_content.py <script.yaml> <out_dir> --model-dir <dir>
  out_dir is normally app/assets/content/<id> (also add it to app/pubspec.yaml assets).

Each sentence is synthesized separately, so sentence timestamps are exact.
Speech speed is tuned iteratively until the measured wpm of the whole clip
is close to the level's target.
"""
import argparse, json, re, subprocess, sys, tempfile
from pathlib import Path

import numpy as np
import soundfile as sf
import yaml
from kokoro_onnx import Kokoro

SR = 24000
SENT_RE = re.compile(r"(?<=[.!?])\s+")
WORD_RE = re.compile(r"[A-Za-z0-9']+")


def split_sentences(text):
    return [s.strip() for s in SENT_RE.split(text.strip()) if s.strip()]


def synth(k, text, voice, speed):
    audio, sr = k.create(text, voice=voice, speed=speed, lang="en-gb" if voice[0] == "b" else "en-us")
    assert sr == SR
    # trim leading/trailing near-silence so pauses are controlled by us
    idx = np.where(np.abs(audio) > 0.01)[0]
    return audio[max(idx[0] - 240, 0): idx[-1] + 480] if len(idx) else audio


def build(k, spec, speed):
    pause = np.zeros(int(SR * spec["pause_ms"] / 1000), dtype=np.float32)
    chunks, sentences, t = [pause[: SR // 4]], [], SR // 4
    for speaker, line in spec["lines"]:
        voice = spec["speakers"][speaker]
        for s in split_sentences(line):
            a = synth(k, s, voice, speed).astype(np.float32)
            sentences.append({
                "idx": len(sentences), "speaker": speaker, "text": s,
                "start_ms": round(t * 1000 / SR), "end_ms": round((t + len(a)) * 1000 / SR),
            })
            chunks += [a, pause]
            t += len(a) + len(pause)
    audio = np.concatenate(chunks)
    words = sum(len(WORD_RE.findall(s["text"])) for s in sentences)
    wpm = words / (len(audio) / SR / 60)
    return audio, sentences, words, wpm


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("script"); ap.add_argument("out_dir")
    ap.add_argument("--model-dir", required=True)
    a = ap.parse_args()
    spec = yaml.safe_load(Path(a.script).read_text())
    md = Path(a.model_dir)
    k = Kokoro(str(md / "kokoro-v1.0.onnx"), str(md / "voices-v1.0.bin"))

    speed = 1.0
    for _ in range(5):
        audio, sentences, words, wpm = build(k, spec, speed)
        err = spec["target_wpm"] / wpm
        print(f"  speed={speed:.2f} wpm={wpm:.0f} target={spec['target_wpm']}", file=sys.stderr)
        if abs(err - 1) < 0.04:
            break
        speed = float(np.clip(speed * err, 0.5, 2.0))

    out = Path(a.out_dir); out.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        sf.write(tmp.name, audio, SR)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name,
                        "-ac", "1", "-b:a", "64k", str(out / "audio.mp3")], check=True)
    meta = {k_: spec[k_] for k_ in ("id", "level", "track", "title")}
    meta.update({
        "duration_ms": round(len(audio) * 1000 / SR), "words": words,
        "measured_wpm": round(wpm), "tts": {"engine": "kokoro-v1.0", "speed": round(speed, 3),
                                             "voices": spec["speakers"]},
        "sentences": sentences,
    })
    (out / "content.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False))
    print(f"{spec['id']}: {meta['duration_ms']/1000:.1f}s, {words} words, {wpm:.0f} wpm (speed {speed:.2f})")


if __name__ == "__main__":
    main()
