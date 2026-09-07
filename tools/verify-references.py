#!/usr/bin/env python3
"""Check that every reference in verse-themes.json exists in quran.json.

Run this after editing the curated theme map. It fails loudly on an invalid
or duplicated reference so a bad "surah:ayah" can never ship.
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
quran = json.loads((ROOT / "quran.json").read_text(encoding="utf-8"))
themes = json.loads((ROOT / "verse-themes.json").read_text(encoding="utf-8"))

errors: list[str] = []
all_refs: set[str] = set()

for theme, refs in themes["themes"].items():
    seen: set[str] = set()
    for ref in refs:
        all_refs.add(ref)
        if ref in seen:
            errors.append(f"{theme}: duplicate reference {ref}")
        seen.add(ref)
        if ref not in quran:
            errors.append(f"{theme}: {ref} is not in quran.json")

known_themes = set(themes["themes"])
for signal, wanted in themes["context"].items():
    for theme in wanted:
        if theme not in known_themes:
            errors.append(f"context.{signal}: unknown theme {theme!r}")

if errors:
    print("FAIL")
    for e in errors:
        print("  " + e)
    sys.exit(1)

print(f"OK — {len(all_refs)} unique references across {len(known_themes)} themes, all valid")
for theme, refs in themes["themes"].items():
    print(f"\n{theme} ({len(refs)})")
    for ref in refs:
        print(f"  {ref:8} {quran[ref]['surah']} — {quran[ref]['text'][:70]}")
