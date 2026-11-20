"""Add per-sentence translations to content bundles.

Usage: python apply_translations.py --content ../../app/assets/content [--lang ko]

Reads translations/<lang>.yaml ({content_id: [sentence translations]}) and
writes each one into the matching sentence of <id>.json as field <lang>.
The list length must equal the number of sentences, otherwise it fails.
"""
import argparse
import json
import sys
from pathlib import Path

import yaml


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--content", required=True)
    ap.add_argument("--lang", default="ko")
    a = ap.parse_args()
    tr = yaml.safe_load((Path(__file__).parent / "translations" / f"{a.lang}.yaml").read_text())
    content = Path(a.content)
    errors = 0
    for f in sorted(content.glob("*.json")):
        d = json.loads(f.read_text())
        t = tr.get(d["id"])
        if t is None:
            print(f"missing translation: {d['id']}")
            errors += 1
            continue
        if len(t) != len(d["sentences"]):
            print(f"count mismatch {d['id']}: {len(t)} translations, {len(d['sentences'])} sentences")
            errors += 1
            continue
        for s, k in zip(d["sentences"], t):
            s[a.lang] = k
        f.write_text(json.dumps(d, indent=2, ensure_ascii=False))
    print(f"done, {errors} problem(s)")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
