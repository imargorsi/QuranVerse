# Attribution

## Quran translation

The verse text bundled in this plugin (`quran.json`, built from `quran_en.json`)
is the **English translation by Umm Muhammad (Saheeh International)**.

- Translator: **Saheeh International** (Umm Muhammad)
- Immediate text source: **[Tanzil.net](https://tanzil.net/trans/en.sahih)**
  (`en.sahih`)
- Redistributed via: **[risan/quran-json](https://github.com/risan/quran-json)**
  v3.1.2, compiled by [Risan Bagja Pradana](https://risanb.com)
- License: **[CC-BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)**
  — full text in [`LICENSE-DATA.txt`](LICENSE-DATA.txt)

The translation text is reproduced **verbatim**. It is not edited, paraphrased,
re-ordered, or mixed with any other translation. Only the surrounding structure
is changed: `tools/build-quran-json.py` keys each verse by `"surah:ayah"` and
drops the Arabic text, transliteration, and per-surah metadata, since V1
displays the English translation only. The script does no text processing —
`tools/verify-references.py` checks the result against the curated references.

### Share-alike

`quran.json` and `quran_en.json` remain under CC-BY-SA 4.0. Anyone modifying and
redistributing that data must keep it under the same license and preserve this
attribution. The plugin code (everything else) is MIT — see [`LICENSE`](LICENSE).

## Author

Plugin developed by **AR Gorsi** ([@imargorsi](https://github.com/imargorsi)),
2026. Code licensed MIT.

## Architectural reference

The plugin's shape — a `bar-widget` manifest with a `BarWidget.qml` entry point
that loads `Panel.qml`, plus a headless model — follows Omarchy's built-in
`omarchy.clock` plugin and the
[official plugin guide](https://plugins.omarchy.org/develop.html). The idea was
prompted by
[SteveHNH/omarchy-bible-verse-plugin](https://github.com/SteveHNH/omarchy-bible-verse-plugin).
No code was copied from it: that plugin fetches its text from a network API at
runtime, whereas this one is entirely offline and selects verses with local
contextual logic.
