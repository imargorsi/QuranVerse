#!/usr/bin/env python3
"""Normalize risan/quran-json's quran_en.json into the shape the plugin uses.

Source : quran_en.json  (risan/quran-json v3.1.2, English = Saheeh International,
         sourced from tanzil.net, licensed CC-BY-SA 4.0)
Output : quran.json      { "<surah>:<ayah>": { "surah": <name>, "ayah": <n>,
                                               "text": <english translation> } }

Only the English translation and the data the popup shows are kept; the Arabic
text, transliteration, revelation type and per-surah metadata are dropped
(V1 is English-only).

The translation text is copied verbatim. Do not edit it here.
"""

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "quran_en.json"
OUT = ROOT / "quran.json"


def main() -> None:
    surahs = json.loads(SRC.read_text(encoding="utf-8"))

    verses: dict[str, dict] = {}
    for surah in surahs:
        name = surah["transliteration"]
        for verse in surah["verses"]:
            ayah = verse["id"]
            verses[f"{surah['id']}:{ayah}"] = {
                "surah": name,
                "ayah": ayah,
                "text": verse["translation"],
            }

    # Compact but one verse per line, so diffs on a data refresh stay readable.
    with OUT.open("w", encoding="utf-8") as fh:
        fh.write("{\n")
        items = list(verses.items())
        for i, (ref, data) in enumerate(items):
            comma = "," if i < len(items) - 1 else ""
            fh.write(f"  {json.dumps(ref)}: {json.dumps(data, ensure_ascii=False)}{comma}\n")
        fh.write("}\n")

    print(f"wrote {len(verses)} verses to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
