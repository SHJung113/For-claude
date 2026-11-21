"""Build a YouTube learning pack (JSON) for the app.

Usage:
    python make_pack.py spec.yaml [more.yaml ...] --out out.json

A spec holds the cleaned-up sentences (speaker, English, Korean) of one
chapter plus key expressions, or several chapters under `packs:` sharing
videoId/source/channel. With more than one pack the output is a bundle
({"type": "listenup-youtube-bundle", "packs": [...]}) the app imports at once. `source` points to the parsed transcript JSON
(from parse_transcript.py). Sentence times are estimated by aligning the
cleaned words to the timestamped caption words; inside a caption line, words
are assumed to be evenly spaced, so times are approximate (about ±0.5 s).

Packs contain transcript text, which is copyrighted: keep them out of the
public repository.
"""
import argparse
import difflib
import json
import re
from pathlib import Path

import yaml

WORD_RE = re.compile(r"[a-z0-9']+", re.I)
PAD_START, PAD_END = 0.25, 0.35  # seconds of margin around each sentence


def caption_words(segments, chapter):
    """[(word, time, line_end)] for one chapter, spreading each line's words evenly."""
    out = []
    for s in segments:
        if s["noise"] or (s["chapter"] or "") != (chapter or ""):
            continue
        words = WORD_RE.findall(s["text"].lower())
        span = min(s["end"] - s["start"], 12)
        for i, w in enumerate(words):
            out.append((w, s["start"] + span * i / max(len(words), 1), s["start"] + span))
    return out


def check_spec(spec):
    """Refuse skeleton leftovers from new_spec.py."""
    problems = []
    for i, (speaker, en, ko) in enumerate(spec["sentences"]):
        if speaker in ("?", "") or not ko.strip():
            problems.append(f"  sentence {i}: speaker={speaker!r} ko={ko!r} :: {en}")
    if spec.get("title", "").startswith("TODO"):
        problems.append("  title is still TODO")
    if problems:
        raise SystemExit(f"unfinished spec for chapter {spec.get('chapter')!r}:\n" + "\n".join(problems[:10]))


def build_pack(spec, base_dir):
    check_spec(spec)
    src = json.loads((base_dir / spec["source"]).read_text(encoding="utf-8"))
    cap = caption_words(src["segments"], spec["chapter"])
    if not cap:
        raise SystemExit(f"chapter not found in source: {spec['chapter']}")
    cap_tokens = [w for w, _, _ in cap]

    clean_tokens, owner = [], []  # owner[i] = sentence index of clean token i
    for si, (_, en, _) in enumerate(spec["sentences"]):
        for w in WORD_RE.findall(en.lower()):
            clean_tokens.append(w)
            owner.append(si)

    mapping = {}
    sm = difflib.SequenceMatcher(None, clean_tokens, cap_tokens, autojunk=False)
    for blk in sm.get_matching_blocks():
        for k in range(blk.size):
            mapping[blk.a + k] = blk.b + k
    matched = len(mapping) / len(clean_tokens)

    sentences = []
    for si, (speaker, en, ko) in enumerate(spec["sentences"]):
        idx = [mapping[i] for i, o in enumerate(owner) if o == si and i in mapping]
        if not idx:
            raise SystemExit(f"no caption match for sentence {si}: {en}")
        first, last = min(idx), max(idx)
        start = cap[first][1]
        # End at the next word, but never past the caption line (music gaps).
        nxt = cap[last + 1][1] if last + 1 < len(cap) else cap[last][1] + 0.6
        nxt = min(nxt, cap[last][2])
        sentences.append({"idx": si, "speaker": speaker, "text": en, "ko": ko,
                          "start_ms": round(max(start - PAD_START, 0) * 1000),
                          "end_ms": round((nxt + PAD_END) * 1000)})

    words = len(clean_tokens)
    seconds = (sentences[-1]["end_ms"] - sentences[0]["start_ms"]) / 1000
    pack = {
        "type": "listenup-youtube-pack", "version": 1,
        "videoId": spec["videoId"], "title": spec["title"],
        "channel": spec.get("channel", ""), "chapter": spec["chapter"],
        "wpm": round(words / (seconds / 60)),
        "sentences": sentences,
        "expressions": [{"en": e, "ko": k, "note": nt} for e, k, nt in (spec.get("expressions") or [])],
        "notes": spec.get("notes") or [],
    }
    print(f"{pack['title']}: {len(sentences)} sentences, {words} words, {pack['wpm']} wpm, "
          f"{matched:.0%} of words aligned to captions")
    return pack


def specs_in(path):
    d = yaml.safe_load(Path(path).read_text(encoding="utf-8"))
    if "packs" not in d:
        yield d
        return
    shared = {k: v for k, v in d.items() if k != "packs"}
    for p in d["packs"]:
        yield {**shared, **p}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("specs", nargs="+")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    packs = []
    for f in a.specs:
        for spec in specs_in(f):
            packs.append(build_pack(spec, Path(f).parent))
    out = packs[0] if len(packs) == 1 else {
        "type": "listenup-youtube-bundle", "version": 1, "packs": packs}
    Path(a.out).write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote {len(packs)} pack(s) to {a.out}")


if __name__ == "__main__":
    main()
