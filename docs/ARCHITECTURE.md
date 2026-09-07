# Architecture

```
quran_en.json ──(tools/build-quran-json.py)──▶ quran.json      full English text
                                               verse-themes.json  curated map
                                                    │
                                                    ▼
        BarWidget.qml ──owns──▶ VerseModel.qml ── Selection.js ──▶ { reference, surah, ayah, text }
        (bar icon, entry)       (date · context · deterministic pick · cache)
              │                                   │
              │ Loader + inject                   │ model
              ▼                                   ▼
                                Panel.qml
                    (themed popup · layout · typography)
```

The three-file split follows Omarchy's built-in `omarchy.clock` plugin, which
the [official plugin guide](https://plugins.omarchy.org/develop.html) names as
the reference for a bar widget with a details panel:

| File | Omarchy role | Here |
|------|--------------|------|
| `BarWidget.qml` | manifest entry point | bar icon, owns the model, `Loader`s the panel, forwards its lifecycle |
| `Panel.qml` | nested popup | layout, typography, theme colors — nothing else |
| `VerseModel.qml` | (the clock's `Model.js`, but stateful) | date, context, deterministic pick, cache + data I/O |
| `Selection.js` | pure logic helper | context → theme → verse; `node`-testable |

## `manifest.json`

One `bar-widget` kind, `entryPoints.barWidget: "BarWidget.qml"`.
`defaultSection: "right"`, `allowMultiple: false`. No `schema` — V1 has nothing
to configure.

## `BarWidget.qml` — the entry point

Extends `qs.Ui`'s `BarWidget`.

- **Bar icon** — a `BarIconButton` with nerd-font glyph `U+F02D` (nf-fa-book).
  Minimal width, follows `bar.barForeground`, dims when data failed to load.
  Any click toggles the popup. Tooltip is the reference.
- **Model** — instantiates one `VerseModel`. It lives here, not in the popup,
  so today's reference is ready for the tooltip whether or not the popup was
  ever opened.
- **Panel** — a `Loader` (`active: true`) on `Panel.qml`; `injectPanel()` hands
  the panel `bar`, `settings`, the anchor button, `hostWidget`, and `model`,
  the way `omarchy.clock` injects its panel.
- **Lifecycle** — forwards `opened` / `open()` / `close()` / `togglePanel()`
  and the `closeForPopoutSwitch` / `popoutSwitchClosing` pair the bar's popout
  coordinator needs. An `IpcHandler` on the plugin id exposes
  `open`/`close`/`show`/`hide`/`toggle`/`status`.

## `Panel.qml` — the view

Extends `qs.Ui`'s `Panel` (shared bar-popup base: IPC-backed open state and
controller). All colors are `bar.foreground` or a `Qt.darker()` of it; all
fonts are `bar.fontFamily` at a `Style.font.*` size — nothing hard-coded, so a
theme switch needs no code path of its own.

- **Popup** — a `KeyboardPanel` (the layer-shell popup the first-party panels
  use: outside-click and `Esc` dismissal, bar-relative positioning, `Tab` to
  the neighbouring panel). Inside: a `Flickable` wrapping a centered `Column`
  of three `Text` items — title, verse, reference. Long verses wrap; if they
  exceed the height cap the `Flickable` scrolls.
- `open()` calls `model.recompute()` first, so a popup opened just after
  midnight shows the new day's verse rather than yesterday's.
- Reads `model.ready` / `model.errorText` / `model.verseText` /
  `model.surahName` / `model.reference`. No selection logic.

## `VerseModel.qml` — the model

An `Item` (no visuals). Responsibilities:

- **Date** — `new Date()`, plus one hourly `Timer` re-running `recompute()` so
  the verse rolls over at local midnight even if the popup is never touched.
- **Data files**
  - `verse-themes.json` — small, `FileView` on `Qt.resolvedUrl(...)`, loaded at
    startup.
  - `quran.json` — ~1.2 MB. Its `FileView` has **no path** until
    `ensureQuranLoading()` sets one, and `onLoaded` is guarded against a double
    parse. A day whose verse is already cached never triggers it.
- **Selection** — delegates to `Selection.js`, then looks the chosen
  `"surah:ayah"` up in the parsed `quran.json`.
- **Cache / recent history** — the plugin's one and only write, a small JSON
  file at `~/.local/state/omarchy/quran-verse.json`:

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

  If `date` is today, the verse is served straight from here — this guarantees
  "same day = same verse" across popup opens and shell restarts, and keeps the
  big dataset unparsed. `recent` (capped at 24) lets the picker skip verses
  shown in the last few weeks. Missing or unreadable cache is never fatal.

- **Errors** — any load or parse failure sets `errorText` to a single
  user-facing sentence, `"Unable to load Quran data."` No stack traces reach
  the UI. A verse already on screen is kept if a later refresh fails.

`recompute()` is guarded so it can be called from any async load callback in
any order and only acts once everything it needs is ready.

## `Selection.js` — pure logic

No QML imports, no state, `module.exports` at the bottom so plain `node` can
test it (`tools/test-selection.cjs`). Same inputs, same output.

```
date ──▶ contextSignals()  ──▶ preferredThemes()  ──▶ theme  ──▶ verse
         [dayPart, friday?,     (from verse-themes    hash(date)   hash(date|theme),
          monthStart/End?]       .context)            % themes     walk past recents
```

`hashString` is FNV-1a/32. See [CONTEXT-SELECTION.md](CONTEXT-SELECTION.md).

## Data separation

Content, curation, logic, and view change independently:

| Change | Edit |
|--------|------|
| A different or newer translation | `quran_en.json` → rebuild `quran.json` |
| Which verses belong to a theme | `verse-themes.json` (`themes`) |
| Which themes a context prefers | `verse-themes.json` (`context`) |
| The picking algorithm | `Selection.js` |
| How the popup looks | `Panel.qml` |

## Future

V1 leaves room for, without a rewrite:

- **Arabic / transliteration / more translations** — `build-quran-json.py`
  already sees those fields upstream; add them to the normalized entry and to
  the `Panel.qml` layout.
- **Hijri calendar / Ramadan / special days** — add signal keys in
  `contextSignals()` and matching entries in `verse-themes.json`'s `context`.
- **Random mode / user-chosen themes / settings UI** — add a `schema` to the
  manifest's `barWidget` block; read it via `setting()` (available on both
  `BarWidget` and `Panel`).
- **Notifications** — a right-click branch in `BarWidget.qml`'s `onPressed`
  calling `omarchy-notification-send`.
