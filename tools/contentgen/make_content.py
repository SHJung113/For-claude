"""Build content bundles (<id>.mp3 + <id>.json) from script YAML files.

Usage:
  python make_content.py levels/L01.yaml [more.yaml ...] --out ../../app/assets/content --model-dir <dir>

A YAML file is either a level file (level, target_wpm, pause_ms, contents: [...])
or a single script (id, level, target_wpm, pause_ms, lines, ...).
Voices come from characters.yaml, overridable per script with `speakers:`.
Existing bundles are skipped unless --force.

Each sentence is synthesized separately, so sentence timestamps are exact.
Speech speed is tuned until the measured wpm is close to the level target.
"""
import argparse, json, re, subprocess, sys, tempfile
from pathlib import Path

import numpy as np
import soundfile as sf
import yaml
from kokoro_onnx import Kokoro

SR = 24000
SENT_RE = re.compile(r"(?<!\bMr\.)(?<!\bMs\.)(?<!\bDr\.)(?<!\bMrs\.)(?<=[.!?])\s+")
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


def scripts_in(path):
    d = yaml.safe_load(Path(path).read_text())
    if "contents" not in d:
        yield d
        return
    for c in d["contents"]:
        yield {"level": d["level"], "target_wpm": d["target_wpm"], "pause_ms": d["pause_ms"], **c}


def make(k, spec, out):
    speed = 1.0
    for _ in range(5):
        audio, sentences, words, wpm = build(k, spec, speed)
        err = spec["target_wpm"] / wpm
        if abs(err - 1) < 0.04:
            break
        speed = float(np.clip(speed * err, 0.5, 2.0))
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        sf.write(tmp.name, audio, SR)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name,
                        "-ac", "1", "-b:a", "64k", str(out / f"{spec['id']}.mp3")], check=True)
    meta = {k_: spec[k_] for k_ in ("id", "level", "track", "title")}
    meta.update({
        "duration_ms": round(len(audio) * 1000 / SR), "words": words,
        "measured_wpm": round(wpm), "tts": {"engine": "kokoro-v1.0", "speed": round(speed, 3),
                                             "voices": spec["speakers"]},
        "sentences": sentences,
    })
    (out / f"{spec['id']}.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False))
    print(f"{spec['id']}: {meta['duration_ms']/1000:.1f}s, {words} words, "
          f"{wpm:.0f}/{spec['target_wpm']} wpm (speed {speed:.2f})", flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--out", required=True)
    ap.add_argument("--model-dir", required=True)
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    here = Path(__file__).parent
    chars = yaml.safe_load((here / "characters.yaml").read_text())
    md = Path(a.model_dir)
    k = Kokoro(str(md / "kokoro-v1.0.onnx"), str(md / "voices-v1.0.bin"))
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    for f in a.files:
        for spec in scripts_in(f):
            if not a.force and (out / f"{spec['id']}.json").exists():
                continue
            used = {sp for sp, _ in spec["lines"]}
            spec["speakers"] = {sp: (spec.get("speakers") or {}).get(sp) or chars[sp] for sp in used}
            make(k, spec, out)


if __name__ == "__main__":
    main()
