# Changelog

## 1.0.0 — 2026-09-07

First release.

- Bar-widget plugin for Omarchy (`omarchy-shell`): a book icon in the bar, a
  minimal popup with one verse — English translation, surah name, ayah number.
- Fully offline. The complete Saheeh International English translation (6236
  verses) is bundled as `quran.json`; no network request at runtime.
- Deterministic daily selection with a small contextual layer: day part,
  Friday, and month boundaries nudge the verse toward a fitting theme
  (13 themes, ~83 curated references). Seeded by the local date via FNV-1a.
- Today's verse and a 24-entry recent-verse history are cached in
  `~/.local/state/omarchy/quran-verse.json`, so repeated opens are stable and
  the large dataset is parsed at most once a day.
- Theme-aware: colors and fonts come entirely from the active Omarchy theme.
- Selection logic isolated in `Selection.js` and unit-tested with node.
- Structure follows Omarchy's built-in `omarchy.clock`: `BarWidget.qml` entry
  point → `Panel.qml` popup → `VerseModel.qml` + `Selection.js` logic.

Developed by AR Gorsi. English translation: Saheeh International, via
[risan/quran-json](https://github.com/risan/quran-json), CC-BY-SA 4.0.
