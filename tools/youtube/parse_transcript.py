"""Parse a transcript copied from YouTube's "Show transcript" panel.

The copied text looks like this (Korean UI; timestamp, its spoken form, text):
    챕터 1: Ordering pizza
    0:1414초luigi's pizza how can i help you
    1:001분yes that's right
    [Music] lines, chapter headings and UI noise are handled.

Usage:
    python parse_transcript.py transcript.txt            # print analysis
    python parse_transcript.py transcript.txt --json out.json

Transcript text is copyrighted material: keep inputs and outputs out of the
public repository (use a local folder).
"""
import argparse
import json
import re
import sys

LINE_RE = re.compile(
    r"^(?P<ts>(?:\d+:)?\d{1,2}:\d{2})"          # 0:14 / 12:09 / 1:02:03
    r"(?:\d+시간\s?)?(?:\d+분\s?)?(?:\d+초)?"     # spoken form shown by the Korean UI
    r"(?P<text>.*)$"
)
CHAPTER_RE = re.compile(r"^(?:챕터|Chapter)\s*\d+\s*[:：]\s*(?P<title>.+)$", re.I)
NOISE_RE = re.compile(r"^\[(?:music|applause|laughter|음악|박수)\]$", re.I)
WORD_RE = re.compile(r"[a-z0-9']+(?:-[a-z0-9']+)*", re.I)

# Level speed targets from docs/CURRICULUM.md
LEVEL_WPM = [75, 85, 95, 100, 105, 110, 120, 125, 130, 135,
             140, 145, 150, 155, 160, 165, 170, 175, 185, 195]


def to_seconds(ts):
    sec = 0
    for part in ts.split(":"):
        sec = sec * 60 + int(part)
    return sec


def parse(text):
    """Returns (chapters, segments). Each segment: start, end, text, chapter."""
    chapters, raw, chapter = [], [], None
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        m = CHAPTER_RE.match(line)
        if m:
            chapter = m.group("title").strip()
            chapters.append(chapter)
            continue
        m = LINE_RE.match(line)
        if not m:
            continue  # UI noise such as "동영상 시간 동기화"
        raw.append((to_seconds(m.group("ts")), m.group("text").strip(), chapter))
    segments = []
    for i, (start, txt, ch) in enumerate(raw):
        end = raw[i + 1][0] if i + 1 < len(raw) else start + 5
        segments.append({"start": start, "end": end, "text": txt, "chapter": ch,
                         "noise": bool(NOISE_RE.match(txt)) or not txt})
    return chapters, segments


def analyze(segments, max_gap=12):
    speech = [s for s in segments if not s["noise"]]
    words = sum(len(WORD_RE.findall(s["text"])) for s in speech)
    # A caption line covers speech until the next line; cap long gaps (music, pauses).
    seconds = sum(min(s["end"] - s["start"], max_gap) for s in speech)
    wpm = words / (seconds / 60) if seconds else 0
    level = min(range(20), key=lambda i: abs(LEVEL_WPM[i] - wpm)) + 1
    return {"segments": len(speech), "words": words, "speech_seconds": seconds,
            "wpm": round(wpm), "level_by_speed": level}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--json")
    a = ap.parse_args()
    chapters, segments = parse(open(a.file, encoding="utf-8").read())
    info = analyze(segments)
    info["chapters"] = chapters
    print(json.dumps(info, ensure_ascii=False, indent=2))
    if a.json:
        json.dump({"chapters": chapters, "segments": segments, "analysis": info},
                  open(a.json, "w", encoding="utf-8"), ensure_ascii=False, indent=2)


if __name__ == "__main__":
    sys.exit(main())
