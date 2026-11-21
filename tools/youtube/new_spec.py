"""Turn a pasted transcript into a pack-spec skeleton to finish by hand.

Usage:
    python new_spec.py request.txt --out-dir youtube-local/<slug>

Input: text copied from the app ("ListenUp 해석 요청" + link + chapters +
"m:ss text" lines) or from YouTube's "Show transcript" panel; a YouTube link
anywhere in the text gives the video id (or pass --video-id).

Writes into the out dir:
    transcript.json  parsed captions (source for make_pack.py)
    spec.yaml        one entry per chapter; every caption line is pre-filled
                     as a sentence ["?", "<caption>", ""] to be rewritten:
                     split into real sentences, fix ASR errors, set speakers,
                     add Korean, add expressions.

Everything here is copyrighted transcript text: keep it out of git
(youtube-local/ is ignored).
"""
import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from parse_transcript import analyze, parse  # noqa: E402

ID_RES = [
    re.compile(r"youtu\.be/([A-Za-z0-9_-]{11})"),
    re.compile(r"[?&]v=([A-Za-z0-9_-]{11})"),
    re.compile(r"youtube\.com/(?:shorts|embed|live)/([A-Za-z0-9_-]{11})"),
]


def video_id(text):
    for r in ID_RES:
        m = r.search(text)
        if m:
            return m.group(1)
    return None


def yq(s):
    """YAML double-quoted string."""
    return json.dumps(s, ensure_ascii=False)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--video-id")
    ap.add_argument("--channel", default="Easy English")
    a = ap.parse_args()

    text = Path(a.file).read_text(encoding="utf-8")
    vid = a.video_id or video_id(text)
    if not vid:
        sys.exit("no YouTube link found: pass --video-id")
    chapters, segments = parse(text)
    for s in segments:
        s["chapter"] = s["chapter"] or ""
    out = Path(a.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    (out / "transcript.json").write_text(
        json.dumps({"chapters": chapters, "segments": segments}, ensure_ascii=False, indent=2),
        encoding="utf-8")

    names = chapters or [""]
    lines = [f"videoId: {vid}", "source: transcript.json", f"channel: {yq(a.channel)}", "packs:"]
    for ch in names:
        segs = [s for s in segments if s["chapter"] == ch and not s["noise"]]
        if not segs:
            continue
        info = analyze(segs)
        title = ch.title() if ch else "TODO title"
        lines += [f"  # {len(segs)} caption lines, ~{info['wpm']} wpm (≈L{info['level_by_speed']})",
                  f"  - chapter: {yq(ch)}", f"    title: {yq(title)}", "    sentences:"]
        for s in segs:
            lines.append(f"      - [\"?\", {yq(s['text'])}, \"\"]")
        lines += ["    expressions:", "      # - [\"English\", \"한국어\", \"메모\"]", "    notes: []"]
    (out / "spec.yaml").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"video {vid}: {len(names)} chapter(s), {sum(not s['noise'] for s in segments)} caption lines")
    print(f"-> {out / 'spec.yaml'} (rewrite every sentence), {out / 'transcript.json'}")


if __name__ == "__main__":
    main()
