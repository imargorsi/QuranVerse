# Architecture

```
quran_en.json ──(tools/build-quran-json.py)──▶ quran.json      full English text
                                               verse-themes.json  curated map
                                                    │
                                                    ▼
                            Service.qml  ── Selection.js ──▶ today's { reference, surah, ayah, text }
                            (date · context · deterministic pick · cache)
                                                    │
                                                    ▼
                                              Panel.qml
                                   (bar icon · themed popup · layout)
```

The split mirrors Omarchy's own bar panels (`omarchy.clock`, `omarchy.weather`):
a headless piece that produces a normalized value, and a view that only draws.

## `manifest.json`

Declares one `bar-widget` kind with `Panel.qml` as its entry point.
`defaultSection: "right"`, `allowMultiple: false`. No settings schema — V1 has
nothing to configure.

## `Panel.qml` — the view

Extends `qs.Ui`'s `Panel` (the shared bar-popup base: IPC lifecycle,
`open`/`close`/`toggle`/`opened`, `bar` injection).

- **Bar icon** — a `BarIconButton` with nerd-font glyph `U+F02D` (nf-fa-book).
  Minimal width, follows `bar.barForeground`, dims when data failed to load.
  Left-click toggles the popup. Tooltip is the reference.
- **Popup** — a `KeyboardPanel` (the same layer-shell popup the first-party
  panels use: outside-click and `Esc` dismissal, bar-relative positioning,
  `Tab` to the neighbouring panel). Inside: a `Flickable` wrapping a centered
  `Column` of three `Text` items — title, verse, reference. Long verses wrap;
  if they somehow exceed the height cap the Flickable scrolls.
- **Colors and fonts** — every color is `bar.foreground` or a `Qt.darker()` of
  it; every font is `bar.fontFamily` at a `Style.font.*` size. Nothing is
  hard-coded, so a theme switch is picked up with no code path of its own.

The view holds no selection logic. It reads `verse.ready`, `verse.errorText`,
`verse.verseText`, `verse.surahName`, `verse.reference`.

## `Service.qml` — the model

An `Item` (no visuals). Responsibilities:

- **Date** — `new Date()`, plus one hourly `Timer` that re-runs `recompute()`
  so the verse rolls over at local midnight without the popup being touched.
- **Data files**
  - `verse-themes.json` — small, loaded at startup via a `FileView` on
    `Qt.resolvedUrl(...)`.
  - `quran.json` — ~1.2 MB. Its `FileView` has **no path** until
    `ensureQuranLoading()` sets one. A day whose verse is already in the cache
    never triggers that load or parse.
- **Selection** — delegates to `Selection.js` (below). Looks the chosen
  `"surah:ayah"` up in the parsed `quran.json`.
- **Cache / recent history** — one small JSON file at
  `~/.local/state/omarchy/quran-verse.json`:

  ```json
  {
    "date": "2026-09-07",
    "reference": "16:97",
    "surah": "An-Nahl",
    "ayah": 97,
    "text": "...",
    "theme": "good_deeds",
    "recent": ["16:97", "2:153", "..."]
  }
  ```

  If `date` is today, the verse is served straight from here — this is what
  guarantees "same day = same verse" across popup opens and shell restarts, and
  what keeps the big dataset unparsed. `recent` (capped at 24) lets the picker
  skip verses shown in the last few weeks. Missing or unreadable cache is never
  fatal; it just means a fresh recompute.

- **Errors** — any load or parse failure sets `errorText` to a single
  user-facing sentence, `"Unable to load Quran data."` No stack traces reach
  the UI. A verse already on screen is kept if a later refresh fails.

`recompute()` is guarded so it can be called from any of the async load
callbacks in any order and only acts once everything it needs is ready.

## `Selection.js` — pure logic

No QML imports, no state, `module.exports` at the bottom so plain `node` can
test it (`tools/test-selection.cjs`). Given the same inputs it always returns
the same output.

```
date ──▶ contextSignals()  ──▶ preferredThemes()  ──▶ theme  ──▶ verse
         [dayPart, friday?,     (from verse-themes    hash(date)   hash(date|theme),
          monthStart/End?]       .context)            % themes     walk past recents
```

`hashString` is FNV-1a/32. See [CONTEXT-SELECTION.md](CONTEXT-SELECTION.md).

## Data separation

Content, curation, logic, and view are four files you can change independently:

| Change | Edit |
|--------|------|
| A different or newer translation | `quran_en.json` → rebuild `quran.json` |
| Which verses belong to a theme | `verse-themes.json` (`themes`) |
| Which themes a context prefers | `verse-themes.json` (`context`) |
| The picking algorithm | `Selection.js` |
| How the popup looks | `Panel.qml` |

## Future

V1 leaves room for, without needing a rewrite:

- **Arabic / transliteration / more translations** — `build-quran-json.py`
  already sees those fields upstream; add them to the normalized entry and to
  the `Panel.qml` layout. Nothing else changes.
- **Hijri calendar / Ramadan / special days** — add signal keys in
  `contextSignals()` and matching entries in `verse-themes.json`'s `context`.
- **Random mode / user-chosen themes / settings UI** — add a `schema` to the
  manifest's `barWidget` block; read it via `setting()` in `Service.qml`.
- **Notifications** — a right-click handler in `Panel.qml` calling
  `omarchy-notification-send`, as the bible-verse plugin does.
