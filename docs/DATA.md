# Data

## Source

`quran_en.json` is the English edition of
[**risan/quran-json**](https://github.com/risan/quran-json) (v3.1.2), committed
here unchanged as the upstream source of truth.

- **Translation:** Umm Muhammad — **Saheeh International**
- **Text source:** [Tanzil.net](https://tanzil.net/trans/en.sahih) (`en.sahih`)
- **License:** [CC-BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
  ([`LICENSE-DATA.txt`](../LICENSE-DATA.txt))
- **Attribution:** [`ATTRIBUTION.md`](../ATTRIBUTION.md)

Upstream shape — an array of 114 surah objects:

```json
{
  "id": 1,
  "name": "الفاتحة",
  "transliteration": "Al-Fatihah",
  "translation": "The Opener",
  "type": "meccan",
  "total_verses": 7,
  "verses": [
    { "id": 1, "text": "بِسۡمِ ٱللَّهِ…", "translation": "In the name of Allah, …" }
  ]
}
```

## Normalized form

`tools/build-quran-json.py` produces `quran.json`: a flat map keyed by
`"<surah>:<ayah>"`, one entry per line.

```json
{
  "1:1": { "surah": "Al-Fatihah", "ayah": 1, "text": "In the name of Allah, the Entirely Merciful, the Especially Merciful" },
  "94:6": { "surah": "Ash-Sharh", "ayah": 6, "text": "Indeed, with hardship [will be] ease" }
}
```

What is kept: the transliterated surah name, the ayah number, and the English
translation — the three things the popup shows. Nothing else.

What is dropped, and why:

| Field | Reason |
|-------|--------|
| Arabic `text` | V1 is English-only; it is ~40% of the file size |
| `transliteration` (verse) | not shown |
| surah `name` (Arabic), `translation`, `type` | not shown |
| `total_verses` | derivable, not needed |

The `translation` string is copied **byte-for-byte**. The build script does no
text processing — no cleanup, no quote substitution, no whitespace collapsing.
If a verse looks odd, it looks that way upstream, and that is left alone.

6236 verses. `quran_en.json` ≈ 2.4 MB → `quran.json` ≈ 1.2 MB.

## Refreshing the data

When risan/quran-json publishes a new revision of the Saheeh International text:

```sh
curl -L https://cdn.jsdelivr.net/npm/quran-json@<version>/dist/quran_en.json -o quran_en.json
python3 tools/build-quran-json.py
python3 tools/verify-references.py   # curated references must still resolve
node    tools/test-selection.cjs
git add quran_en.json quran.json
git commit -m "data: refresh Saheeh International text to quran-json <version>"
```

One-line-per-verse output keeps that diff readable. The refreshed `quran.json`
stays under CC-BY-SA 4.0.

## `verse-themes.json`

Not derived from the dataset — hand-curated, and small on purpose.

```json
{
  "themes": {
    "hope": ["39:53", "94:5", "94:6", "93:5", "12:87", "3:139", "41:30", "65:3"],
    "...": []
  },
  "context": {
    "morning": ["guidance", "gratitude", "hope", "knowledge"],
    "...": []
  }
}
```

- ~83 references across 13 themes (`hope`, `patience`, `mercy`, `forgiveness`,
  `guidance`, `gratitude`, `faith`, `reflection`, `trust`, `hardship`,
  `knowledge`, `good_deeds`, `prayer`). A reference may appear in more than one
  theme (e.g. `94:6` is both `hope` and `hardship`).
- Every reference is checked against `quran.json` by
  `tools/verify-references.py`, which is also where you can eyeball the text of
  each curated verse.
- The full `quran.json` stays bundled regardless — a future "random from the
  whole Quran" mode, or wider theme coverage, needs no new data.
